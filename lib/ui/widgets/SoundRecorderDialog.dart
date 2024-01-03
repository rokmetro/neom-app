
import 'package:flutter/material.dart';
import 'package:illinois/ui/widgets/SmallRoundedButton.dart';
import 'package:illinois/utils/AppUtils.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:rokwire_plugin/service/localization.dart';
import 'package:rokwire_plugin/service/Log.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:rokwire_plugin/utils/utils.dart';
import 'dart:io';

import '../../service/Analytics.dart';

enum RecorderMode{record, play}
class SoundRecorderDialog extends StatefulWidget {
  final RecorderMode? mode;

  const SoundRecorderDialog({super.key, this.mode});

  @override
  _SoundRecorderDialogState createState() => _SoundRecorderDialogState();

  static show(BuildContext context, {RecorderMode?mode}) {
    showDialog(
        context: context,
        builder: (_) =>
            Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.all(Radius.circular(5)),
              child: SoundRecorderDialog(mode: mode),
            )
    );
  }
}

class _SoundRecorderDialogState extends State<SoundRecorderDialog> {
  late PlayerController _controller;

  // late RecorderMode _mode;
  RecorderMode get _mode => _controller.hasRecord ? RecorderMode.play : RecorderMode.record;

  @override
  void initState() {
    // _mode = widget.mode ?? RecorderMode.record;
    _controller = PlayerController(notifyChanged: (fn) =>setStateIfMounted(fn));
    _controller.init();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return SafeArea(child: Container(
        // color: Colors.transparent,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        child: Container(
          padding: EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(5)),
              color: Styles().colors!.background,
            ),
            child: Stack(
                alignment: Alignment.topRight,
                children:[
                  Row(mainAxisSize: MainAxisSize.min, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 38, vertical: 16),
                          child: Column(children: [
                            GestureDetector(
                              onTap:(){
                                  if(_mode == RecorderMode.play){
                                    if(_controller.isPlaying){
                                      _onPausePlay();
                                    }else {
                                      _onPlay();
                                    }
                                  }
                              },
                              onLongPressStart: (_){
                                if(_mode == RecorderMode.record) {
                                  _onStartRecording();
                                }
                              },
                              onLongPressEnd:(_){
                                if(_mode == RecorderMode.record){
                                  _onStopRecording();
                                }
                              } ,
                              child: Container(
                                padding: EdgeInsets.all(12),
                                // height: 48, width: 48,
                                decoration: BoxDecoration(
                                    color: _playButtonColor,
                                    shape: BoxShape.circle,
                                ),
                                child: _playButtonIcon ?? Container()
                              ),
                            ),
                            Container(height: 6,),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              child: Text(_statusText, style: Styles().textStyles?.getTextStyle("widget.detail.regular.fat"),)
                            ),
                            Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                child: Text(_hintText, style: Styles().textStyles?.getTextStyle("widget.item.small"),)
                            ),
                            Container(height: 16,),
                            Row(
                              children: [
                                SmallRoundedButton( rightIcon: Container(),
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                  label: Localization().getStringEx("", "Reset"),
                                  onTap: _onTapReset,
                                  enabled: _resetEnabled,
                                  borderColor: _resetEnabled ? null : Styles().colors?.disabledTextColor,
                                  textColor: _resetEnabled ? null : Styles().colors?.disabledTextColor,
                                ),
                                Container(width: 24,),
                                SmallRoundedButton( rightIcon: Container(),
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                  label: Localization().getStringEx("", "Save"),
                                  onTap: _onTapSave,
                                  enabled: _saveEnabled,
                                  borderColor: _saveEnabled ? null : Styles().colors?.disabledTextColor,
                                  textColor: _saveEnabled ? null : Styles().colors?.disabledTextColor,
                                ),
                            ],),
                          ],)
                        )
                      ]),
                  ]),
                  Semantics(
                      label: Localization().getStringEx('dialog.close.title', 'Close'),
                      button: true,
                      excludeSemantics: true,
                      child: InkWell(
                          onTap: () {
                            _onTapClose();
                          },
                          child: Container( padding: EdgeInsets.all(16), child:
                          Styles().images?.getImage('close', excludeFromSemantics: true)))),
                ]
            )
        )));
  }

  void _onStartRecording(){
    _controller.startRecording();
  }

  void _onStopRecording(){
    _controller.stopRecording().then((value) => _controller.loadPlayer());
  }

  void _onPlay(){
    _controller.playRecord();
  }

  void _onPausePlay(){
    _controller.stopRecord();
  }

  void _onTapSave(){
    //TBD
    AppToast.show("TBD implement SAVE");
    _closeModal();
  }

  void _onTapReset(){
    _controller.resetRecord();
  }

  void _onTapClose() {
    Analytics().logAlert(text: "Sound Recording Dialog", selection: "Close");
    _closeModal();
  }

  void _closeModal() {
    Navigator.of(context).pop();
  }

  Color? get _playButtonColor => _mode == RecorderMode.record && _controller.isRecording ?
    Styles().colors?.fillColorSecondary : Styles().colors?.fillColorPrimary;

  Widget? get _playButtonIcon {
    double iconSize = 58;
    if(_mode == RecorderMode.play){
      return _controller.isPlaying ?
        Container(padding: EdgeInsets.all(20), child: Container(width: 20, height: 20, color: Styles().colors?.white,)) : //TBD
        Styles().images?.getImage('play-circle-white', excludeFromSemantics: true, size: iconSize); //TBD
    } else {
      return Styles().images?.getImage('play-circle-white', excludeFromSemantics: true, size: iconSize); //TBD
    }
  }

  String get _statusText{
    if(_mode == RecorderMode.record){
      return _controller.isRecording ?
        Localization().getStringEx("", "Recording") :
        Localization().getStringEx("", "Record");
    } else {
      return _controller.timerText;
    }
  }

  String get _hintText{
    if(_mode == RecorderMode.record){
      return _controller.isRecording ?
      Localization().getStringEx("", "Release to stop") :
      Localization().getStringEx("", "Hold to record");
    } else {
      return _controller.isPlaying ? Localization().getStringEx("", "Stop listening to your recording"):Localization().getStringEx("", "Listen to your recording");
    }
  }

  bool get _resetEnabled => _mode == RecorderMode.play;

  bool get _saveEnabled => _mode == RecorderMode.play;
}

class PlayerController {
  final Function(void Function()) notifyChanged;

  late Record _audioRecord;
  late AudioPlayer _audioPlayer;
  Duration? _playerTimer;
  String _audioPath = "";
  bool _recording = false;

  PlayerController({required this.notifyChanged});

  void init() {
    _audioRecord = Record();
    _audioPlayer = AudioPlayer();
    _audioPlayer.positionStream.listen((elapsedDuration) {
      notifyChanged(() => _playerTimer = elapsedDuration);
    });
  }

  void dispose() {
    _audioRecord.dispose();
    _audioPlayer.dispose();
  }

  void startRecording() async {
    try {
      Log.d("START RECODING");
      if (await _audioRecord.hasPermission()) {
        notifyChanged(() => _recording = true);
        await _audioRecord.start();
        _recording = await _audioRecord.isRecording();
      }
    } catch (e, stackTrace) {
      Log.d("START RECODING: ${e} - ${stackTrace}");
    }
  }

  Future<void> stopRecording() async {
    Log.d("STOP RECODING");
    try {
      String? path = await _audioRecord.stop();
      _recording = await _audioRecord.isRecording();
      notifyChanged(() {
        _audioPath = path!;
      });
      Log.d("STOP RECODING audioPath = $_audioPath");
    } catch (e) {
      Log.d("STOP RECODING: ${e}");
    }
  }

  Future<void> loadPlayer() async {
    Log.d("AUDIO PREPARING");
    await _audioPlayer.setFilePath(_audioPath);
    notifyChanged(() {});
  }

  void playRecord() async {
    try {
      if (hasRecord) {
        await loadPlayer(); //Reset
        await _audioPlayer.play().then((_) => stopRecord());
      }
    } catch (e) {
      Log.d("AUDIO PLAYING: ${e}");
    }
  }

  void pauseRecord() async {
    try {
      if (_audioPlayer.playing) {
        Log.d("AUDIO PAUSED");
        _audioPlayer.pause();
      }
    } catch (e) {
      Log.d("AUDIO PAUSED: ${e}");
    }
  }

  void stopRecord() async {
    try {
      if (_audioPlayer.playing) {
        Log.d("AUDIO STOPPED");
        _audioPlayer.stop().then((_) => _playerTimer = null);
      }
    } catch (e) {
      Log.d("AUDIO STOPPED: ${e}");
    }
  }

  Future<void> deleteRecording() async {
    if (_audioPath.isNotEmpty) {
      try {
        File file = File(_audioPath);
        if (file.existsSync()) {
          file.deleteSync();
          Log.d("FILE DELETED");
        }
      } catch (e) {
        Log.d("FILE NOT DELETED: ${e}");
      }

      notifyChanged(() {
        _audioPath = "";
      });
    }
  }

  void resetRecord() {
    deleteRecording();
  }

  //Getters

  bool get isRecording => _recording;

  bool get hasRecord => StringUtils.isNotEmpty(_audioPath);

  String get recordPath => _audioPath;

  bool get isPlaying => _audioPlayer.playing;

  String get timerText {
    return "$_playerElapsedTime/$_playerLengthText";
  }

  String get _playerElapsedTime =>
      _playerTimer != null ? displayDuration(_playerTimer!) : "00:00";

  String get _playerLengthText =>
      _audioPlayer.duration != null ? displayDuration(_audioPlayer.duration!) : "00:00";

  String displayDuration(Duration duration) {
    final HH =  (duration.inHours).toString().padLeft(2, '0');
    final mm = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return duration.inHours > 1 ? '$HH:$mm:$ss' : '$mm:$ss';
  }
}