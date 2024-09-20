import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neom/ext/Survey.dart';
import 'package:neom/service/Auth2.dart';
import 'package:neom/ui/surveys/SurveyDetailPanel.dart';
import 'package:neom/ui/widgets/HeaderBar.dart';
import 'package:rokwire_plugin/model/survey.dart';
import 'package:rokwire_plugin/service/localization.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:rokwire_plugin/ui/panels/survey_panel.dart' as rokwire;
class SurveyPanel extends rokwire.SurveyPanel{

  SurveyPanel({required super.survey, super.surveyDataKey, super.inputEnabled, super.backgroundColor,
    super.dateTaken, super.showResult, super.onComplete, super.initPanelDepth, super.defaultResponses,
    super.summarizeResultRules, super.summarizeResultRulesWidget, super.headerBar, super.tabBar,
    super.offlineWidget, super.textStyles});

  factory SurveyPanel.defaultStyles({required dynamic survey, String? surveyDataKey, bool inputEnabled = true,
    DateTime? dateTaken, bool showResult = false, Function(dynamic)? onComplete, int initPanelDepth = 0, Map<String, dynamic>? defaultResponses,
    bool summarizeResultRules = false, Widget? summarizeResultRulesWidget, PreferredSizeWidget? headerBar, Widget? tabBar,
    Widget? offlineWidget}) {
    return SurveyPanel(
      survey: survey,
      surveyDataKey: surveyDataKey,
      inputEnabled: inputEnabled,
      dateTaken: dateTaken,
      showResult: showResult,
      onComplete: onComplete,
      initPanelDepth: initPanelDepth,
      defaultResponses: defaultResponses,
      summarizeResultRules: summarizeResultRules,
      summarizeResultRulesWidget: summarizeResultRulesWidget,
      headerBar: headerBar,
      tabBar: tabBar,
      offlineWidget: offlineWidget,
    );
  }

  @override
  PreferredSizeWidget? buildHeaderBar(BuildContext context, Survey? survey) => ((survey is Survey) && _SurveyHeaderBarTitleWidget.surveyHasDetails(survey)) ?
    HeaderBar(titleWidget: _SurveyHeaderBarTitleWidget(survey), actions: _buildActions(context, survey)) :
    HeaderBar(title: survey?.title, actions: _buildActions(context, survey));

  List<Widget>? _buildActions(BuildContext context, Survey? survey) {
    if (survey != null && (Auth2().isAppAdmin || Auth2().isDebugManager || kDebugMode)) {
      return [
        Semantics(label: Localization().getStringEx('headerbar.panel.survey.settings.title', 'Settings'), hint: Localization().getStringEx('headerbar.panel.survey.settings.hint', ''), button: true, excludeSemantics: true, child:
          InkWell(onTap: () => _onTapSurveySettings(context, survey), child:
            Padding(padding: EdgeInsets.only(top: 16, bottom: 16, right: 16), child:
              Styles().images.getImage('settings-white', excludeFromSemantics: true, color: Styles().colors.iconPrimary),
            )
          )
        )
      ];
    }
    return null;
  }

  void _onTapSurveySettings(BuildContext context, Survey survey) {
    Navigator.push(context, CupertinoPageRoute(builder: (context) => SurveyDetailPanel(survey: survey,)));
  }
}

class _SurveyHeaderBarTitleWidget extends StatelessWidget {
  final Survey survey;

  // ignore: unused_element
  _SurveyHeaderBarTitleWidget(this.survey, {super.key, });

  @override
  Widget build(BuildContext context) {
    Widget? detailWidget = _buildDetailWidget(context);
    return (detailWidget != null) ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _titleWidget,
      detailWidget
    ],) : _titleWidget;
  }

  Widget get _titleWidget =>
      Text(survey.title, style: Styles().textStyles.getTextStyle('header_bar'),);

  static bool surveyHasDetails(Survey survey) =>
    (survey.endDate != null) || survey.isCompleted;

  Widget? _buildDetailWidget(BuildContext context) {
    List<InlineSpan> details = <InlineSpan>[];

    if (survey.endDate != null) {
      details.add(TextSpan(
        text: _endDateDetailText ?? '')
      );
    }

    if (survey.isCompleted) {
      if (details.isNotEmpty) {
        details.add(TextSpan(text: ', '));
      }
      details.add(TextSpan(
        text: Localization().getStringEx('model.public_survey.label.detail.completed', 'Completed'),
        style: Styles().textStyles.getTextStyle('header_bar.detail.highlighted.fat')
      ));
    }

    if (details.isNotEmpty) {
      return RichText(textScaler: MediaQuery.of(context).textScaler, text:
        TextSpan(style: Styles().textStyles.getTextStyle("header_bar.detail"), children: details)
      );
    }
    else {
      return null;
    }
  }


  String? get _endDateDetailText {
    String? endTimeValue = survey.displayEndDate;
    if (endTimeValue != null) {
      final String _valueMacro = '{{end_date}}';
      int? daysDiff = survey.endDateDiff;
      String macroString = ((daysDiff == 0) || (daysDiff == 1)) ?
        Localization().getStringEx('model.public_survey.label.detail.ends.1', 'Ends $_valueMacro') :
        Localization().getStringEx('model.public_survey.label.detail.ends.2', 'Ends on $_valueMacro');
      return macroString.replaceAll(_valueMacro, endTimeValue);
    }
    else {
      return null;
    }
  }

}