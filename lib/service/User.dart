/*
 * Copyright 2020 Board of Trustees of the University of Illinois.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:illinois/model/UserData.dart';
import 'package:illinois/service/AppLivecycle.dart';
import 'package:illinois/service/Auth2.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/FirebaseCrashlytics.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Service.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:http/http.dart' as http;

class User with Service implements NotificationsListener {

  static const String notifyUserUpdated = "edu.illinois.rokwire.user.updated";
  static const String notifyUserDeleted = "edu.illinois.rokwire.user.deleted";
  static const String notifyPrivacyLevelEmpty  = "edu.illinois.rokwire.user.privacy.level.empty";
  static const String notifyVoterUpdated  = "edu.illinois.rokwire.user.voter.updated";

  UserData _userData;

  http.Client _client = http.Client();

  static final User _service = new User._internal();

  factory User() {
    return _service;
  }

  User._internal();

  @override
  void createService() {
    NotificationService().subscribe(this, [
      AppLivecycle.notifyStateChanged,
      FirebaseMessaging.notifyToken,
      Auth2.notifyLogout,
    ]);
  }

  @override
  void destroyService() {
    NotificationService().unsubscribe(this);
  }

  @override
  Future<void> initService() async {

    _userData = Storage().userData;
    
    if (_userData == null) {
      await _createUser();
    } else if (_userData.uuid != null) {
      await _loadUser();
    }
  }

  Set<Service> get serviceDependsOn {
    return Set.from([Storage(), Config()]);
  }

  // NotificationsListener
  @override
  void onNotification(String name, dynamic param) {
    if (name == FirebaseMessaging.notifyToken) {
      _updateFCMToken();
    }
    else if(name == AppLivecycle.notifyStateChanged && param == AppLifecycleState.resumed){
      //_loadUser();
    }
    else if(name == Auth2.notifyLogout){
      _recreateUser(); // Always create userData on logout. // https://github.com/rokwire/illinois-app/issues/29
    }
  }

  // User

  String get uuid {
    return _userData?.uuid;
  }
  
  UserData get data {
    return _userData;
  }

  Future<void> _createUser() async {
    UserData userData = await _requestCreateUser();
    applyUserData(userData);
  }

  Future<void> _recreateUser() async {
    UserData userData = await _requestCreateUser();
    applyUserData(userData, migrateData: true);
  }

  Future<void> _loadUser() async {
    // silently refresh user profile
    requestUser(_userData.uuid).then((UserData userData) {
      if (userData != null) {
        applyUserData(userData, applyCachedSettings: true);
      }
    })
    .catchError((_){
        _clearStoredUserData();
      }, test: (error){return error is UserNotFoundException;});
  }

  Future<void> _updateUser() async {

    if (_userData == null) {
      return;
    }

    // Stop previous request
    if (_client != null) {
      _client.close();
    }

    http.Client client;
    _client = client = http.Client();

    String userUuid = _userData.uuid;
    String url = (Config().userProfileUrl != null) ? "${Config().userProfileUrl}/$userUuid" : null;
    Map<String, String> headers = {"Accept": "application/json","content-type":"application/json"};
    final response = await Network().put(url, body: json.encode(_userData.toJson()), headers: headers, client: _client, auth: NetworkAuth.App);
    String responseBody = response?.body;
    bool success = ((response != null) && (responseBody != null) && (response.statusCode == 200));
    
    if (!success) {
      //error
      String message = "Error on updating user - " + (response != null ? response.statusCode.toString() : "null");
      FirebaseCrashlytics().log(message);
    }
    else if (_client == client) {
      _client = null;
      Map<String, dynamic> jsonData = AppJson.decode(responseBody);
      UserData update = UserData.fromJson(jsonData);
      if (update != null) {
        Storage().userData = _userData = update;
        //_notifyUserUpdated();
      }
    }
    else {
      Log.d("Updating user canceled");
    }

  }

  Future<UserData> requestUser(String uuid) async {
    String url = ((Config().userProfileUrl != null) && (uuid != null) && (0 < uuid.length)) ? '${Config().userProfileUrl}/$uuid' : null;

    final response = await Network().get(url, auth: NetworkAuth.App);

    if(response != null) {
      if (response?.statusCode == 404) {
        throw UserNotFoundException();
      }

      String responseBody = ((response != null) && (response?.statusCode == 200)) ? response?.body : null;
      Map<String, dynamic> jsonData = AppJson.decode(responseBody);
      if (jsonData != null) {
        return UserData.fromJson(jsonData);
      }
    }

    return null;
  }

  Future<UserData> _requestCreateUser() async {
    try {
      final response = await Network().post(Config().userProfileUrl, auth: NetworkAuth.App, timeout: 10);
      if ((response != null) && (response.statusCode == 200)) {
        String responseBody = response.body;
        Map<String, dynamic> jsonData = AppJson.decode(responseBody);
        return UserData.fromJson(jsonData);
      } else {
        return null;
      }
    } catch(e){
      Log.e('Failed to create user');
      Log.e(e.toString());
      return null;
    }
  }

  Future<void> deleteUser() async{
    String userUuid = _userData?.uuid;
    if((Config().userProfileUrl != null) && (userUuid != null)) {
      try {
        await Network().delete("${Config().userProfileUrl}/$userUuid", headers: {"Accept": "application/json", "content-type": "application/json"}, auth: NetworkAuth.App);
      }
      finally {
        _clearStoredUserData();
        _notifyUserDeleted();

        _userData = await _requestCreateUser();

        if (_userData != null) {
          Storage().userData = _userData;
          _notifyUserUpdated();
        }
      }
    }
  }

  void applyUserData(UserData userData, { bool applyCachedSettings = false, bool migrateData = false }) {
    
    // 1. We might need to remove FCM token from current user
    String applyUserUuid = userData?.uuid;
    String currentUserUuid = _userData?.uuid;
    bool userSwitched = (currentUserUuid != null) && (currentUserUuid != applyUserUuid);
    if (userSwitched && _removeFCMToken(_userData)) {
      String url = "${Config().userProfileUrl}/${_userData.uuid}";
      Map<String, String> headers = {"Accept": "application/json","content-type":"application/json"};
      String post = json.encode(_userData.toJson());
      Network().put(url, body: post, headers: headers, auth: NetworkAuth.App);
    }

    // 2. We might need to add FCM token and user roles from Storage to new user
    bool applyUserUpdated = _applyFCMToken(userData);
    if (applyCachedSettings) {
      applyUserUpdated = _updateUserSettingsFromStorage(userData) || applyUserUpdated;
    }

    if(migrateData && _userData != null){
      userData.loadFromUserData(_userData);
      applyCachedSettings = true;
    }

    _userData = userData;
    Storage().userData = _userData;
    Storage().userRoles = userData?.roles;
    Storage().privacyLevel = userData?.privacyLevel;

    if (userData?.privacyLevel == null) {
      Log.d('User: applied null privacy level!');
      NotificationService().notify(notifyPrivacyLevelEmpty, null);
    }

    if (userSwitched) {
      _notifyUserUpdated();
    }
    
    if (applyUserUpdated) {
      _updateUser();
    }
  }

  void _clearStoredUserData(){
    _userData = null;
    Storage().userData = null;
    Auth2().logout();
    Storage().onBoardingPassed = false;
  }

  // FCM Tokens

  void _updateFCMToken() {
    if (_applyFCMToken(_userData)) {
      _updateUser();
    }
  }

  static bool _applyFCMToken(UserData userData) {
    String fcmToken = FirebaseMessaging().token;
    if ((userData != null) && (fcmToken != null)) {
      if (userData.fcmTokens == null) {
        userData.fcmTokens = Set.from([fcmToken]);
        return true;
      }
      else if (!userData.fcmTokens.contains(fcmToken)) {
        userData.fcmTokens.add(fcmToken);
        return true;
      }
    }
    return false;
  }

  static bool _removeFCMToken(UserData userData) {
    String fcmToken = FirebaseMessaging().token;
    if ((userData != null) && (userData.fcmTokens != null) && (fcmToken != null) && userData.fcmTokens.contains(fcmToken)) {
      userData.fcmTokens.remove(fcmToken);
      return true;
    }
    return false;
  }

  // Backward compatability + stability (use last stored roles & privacy if they are missing)
  static bool _updateUserSettingsFromStorage(UserData userData) {
    bool userUpdated = false;

    if (userData != null) {
      if (userData.roles == null) {
        userData.roles = Storage().userRoles;
        userUpdated = userUpdated || (userData.roles != null);
      }

      if (userData.privacyLevel == null) {
        userData.privacyLevel = Storage().privacyLevel;
        userUpdated = userUpdated || (userData.privacyLevel != null);
      }
    }

    return userUpdated;
  }

  // Voter Registration

  void updateVoterRegistration({@required bool registeredVoter}) {
    if ((_userData != null) && (registeredVoter != _userData.registeredVoter)) {
      _userData.registeredVoter = registeredVoter;
      _updateUser().then((_) {
        _notifyUserVoterUpdated();
      });
    }
  }

  bool get isVoterRegistered {
    return _userData?.registeredVoter ?? false;
  }

  void updateVoterByMail({@required bool voterByMail}) {
    if ((_userData != null) && (voterByMail != _userData.voterByMail)) {
      _userData.voterByMail = voterByMail;
      _updateUser().then((_) {
        _notifyUserVoterUpdated();
      });
    }
  }

  bool get isVoterByMail {
    return _userData?.voterByMail;
  }

  void updateVoted({@required bool voted}) {
    if ((_userData != null) && (voted != _userData.voted)) {
      _userData.voted = voted;
      _updateUser().then((_) {
        _notifyUserVoterUpdated();
      });
    }
  }

  bool get didVote {
    return _userData?.voted ?? false;
  }

  void updateVotePlace({@required String votePlace}) {
    if ((_userData != null) && (votePlace != _userData.votePlace)) {
      _userData.votePlace = votePlace;
      _updateUser().then((_) {
        _notifyUserVoterUpdated();
      });
    }
  }

  String get votePlace {
    return _userData?.votePlace;
  }

  // Notifications

  void _notifyUserUpdated() {
    NotificationService().notify(notifyUserUpdated, null);
  }

  void _notifyUserDeleted() {
    NotificationService().notify(notifyUserDeleted, null);
  }

  /*void _notifyUserInterestsUpdated() {
    NotificationService().notify(notifyInterestsUpdated, null);
  }*/

  /*void _notifyUserTagsUpdated() {
    NotificationService().notify(notifyTagsUpdated, null);
  }*/

  void _notifyUserVoterUpdated() {
    NotificationService().notify(notifyVoterUpdated, null);
  }
}

class UserNotFoundException implements Exception{
  final String message;
  UserNotFoundException({this.message});

  @override
  String toString() {
    return message;
  }
}