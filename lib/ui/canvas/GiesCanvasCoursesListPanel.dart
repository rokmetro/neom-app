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

import 'package:flutter/material.dart';
import 'package:neom/model/Analytics.dart';
import 'package:neom/ui/canvas/GiesCanvasCoursesContentWidget.dart';
import 'package:neom/ui/widgets/HeaderBar.dart';
import 'package:neom/ui/widgets/TabBar.dart' as uiuc;
import 'package:rokwire_plugin/service/localization.dart';
import 'package:rokwire_plugin/service/styles.dart';

class GiesCanvasCoursesListPanel extends StatelessWidget with AnalyticsInfo {
  GiesCanvasCoursesListPanel();

  @override
  AnalyticsFeature? get analyticsFeature => AnalyticsFeature.AcademicsGiesCanvasCourses;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: HeaderBar(title: Localization().getStringEx('panel.gies_canvas_courses.header.title', 'My Gies Canvas Courses')),
        body: _scaffoldContent,
        backgroundColor: Styles().colors.white,
        bottomNavigationBar: uiuc.TabBar());
  }

  Widget get _scaffoldContent =>
    SingleChildScrollView(child:
      Padding(padding: EdgeInsets.only(left: 16, right: 16, bottom: 16), child:
        GiesCanvasCoursesContentWidget()
      )
    );
}
