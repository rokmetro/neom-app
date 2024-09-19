import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neom/service/AppDateTime.dart';
import 'package:neom/service/Auth2.dart';
import 'package:neom/ui/widgets/HeaderBar.dart';
import 'package:neom/ui/widgets/RibbonButton.dart';
import 'package:neom/utils/AppUtils.dart';
import 'package:rokwire_plugin/model/auth2.dart';
import 'package:rokwire_plugin/model/event2.dart';
import 'package:rokwire_plugin/model/survey.dart';
import 'package:rokwire_plugin/service/events2.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:rokwire_plugin/service/surveys.dart';
import 'package:rokwire_plugin/utils/utils.dart';

class SurveyDetailPanel extends StatefulWidget {
  final Survey survey;
  final String? surveysLabel;

  SurveyDetailPanel({required this.survey, this.surveysLabel});

  @override
  State<StatefulWidget> createState() => _SurveyDetailPanelState();
}

class _SurveyDetailPanelState extends State<SurveyDetailPanel> {
  Event2? _surveyEvent;
  List<SurveyResponse>? _surveyResponses;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadSurveyResponses();
    _loadSurveyEvent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: HeaderBar(title: widget.survey.title), body: _buildPanelContent(), backgroundColor: Styles().colors.surface);
  }

  Widget _buildPanelContent() {
    return SingleChildScrollView(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildDownloadResults(), _buildEditSurvey()]),
    );
  }

  Widget _buildEditSurvey() {
    return Visibility(
        visible: Auth2().isDebugManager || kDebugMode,
        child: Padding(
          padding: EdgeInsets.only(top: 10),
          child: RibbonButton(
            backgroundColor: Styles().colors.surface,
            border: Border(),
            leftIconKey: 'edit',
          )
        ),
    );
  }

  Widget _buildDownloadResults() {
    List<Widget> downloadWidgets = [
      ScreenUtils.isLarge(context) ? Flexible(flex: 1, child: _buildDownloadWidget(combineResponses: false)) : _buildDownloadWidget(combineResponses: false),
      ScreenUtils.isLarge(context) ? Flexible(flex: 1, child: _buildDownloadWidget(combineResponses: true)) : _buildDownloadWidget(combineResponses: true),
    ];

    return Visibility(
        visible: !widget.survey.isSensitive,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _horizontalDivider,
          Stack(alignment: Alignment.center, children: [
            ScreenUtils.isLarge(context) ? Row(
              children: downloadWidgets,
            ) : Wrap(
              runSpacing: 5,
              spacing: 20,
              children: downloadWidgets,
            ),
            Visibility(visible: _isLoading, child: CircularProgressIndicator(color: Styles().colors.iconDark)),
          ]),
          _horizontalDivider
        ])
    );
  }

  Widget _buildDownloadWidget({bool combineResponses = false}) {
    return Column(children: [
      InkWell(
          onTap: () => _onTapDownloadSurveyResults(combineResponses: combineResponses),
          child: Padding(
              padding: EdgeInsets.only(top: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.center, children: [
                Padding(padding: EdgeInsets.only(right: 10), child: Styles().images.getImage('download')),
                Text('Download Survey Results',
                    style: Styles().textStyles.getTextStyle('widget.button.title.medium.underline'))
              ]))),
      _buildDownloadSubtitleWidget(combineResponses: combineResponses),
      _buildCsvOptionLabelWidget()
    ]);
  }

  Widget _buildDownloadSubtitleWidget({bool combineResponses = false}) {
    return Padding(
        padding: EdgeInsets.only(top: 2),
        child: Row(children: [
          Expanded(
              child: Text(combineResponses ? 'One User Per Row' : 'One User Question Per Row',
                  style: Styles().textStyles.getTextStyle('widget.info.dark.tiny')))
        ]));
  }

  Widget _buildCsvOptionLabelWidget() {
    return Padding(
        padding: EdgeInsets.only(top: 2),
        child: Row(children: [
          Expanded(
              child: Text('Option for .csv',
                  style: Styles().textStyles.getTextStyle('widget.item.small.thin.italic')))
        ]));
  }

  void _onTapDownloadSurveyResults({bool combineResponses = false}) {
    if (_isLoading || widget.survey.isSensitive) {
      return;
    }

    if (CollectionUtils.isEmpty(_surveyResponses)) {
      AppAlert.showDialogResult(context, 'There are no results for that survey, yet.');
      return;
    }
    setStateIfMounted(() {
      _increaseLoadingProgress();
    });

    final String surveyName = widget.survey.title;

    List<String>? accountIds = _surveyResponses?.map((response) => StringUtils.ensureNotEmpty(response.userId)).toList();

    Auth2().filterAccountsBy(accountIds: accountIds!).then((result) {
      List<Auth2Account>? accounts;
      if (result is String) {
        AppAlert.showDialogResult(context, result);
      } else if ((result == null) || ((result is List) && CollectionUtils.isEmpty(result))) {
        AppAlert.showDialogResult(context, 'There are no accounts for the specified account ids.');
      } else if (result is List<Auth2Account>) {
        accounts = result;
      }
      final String defaultEmptyValue = '---';
      final String dateFormat = 'yyyy-MM-dd';
      final String timeFormat = 'HH:mm';
      String eventName = StringUtils.ensureNotEmpty(_surveyEvent?.name, defaultValue: defaultEmptyValue);
      String eventStartDate = StringUtils.ensureNotEmpty(AppDateTime().formatDateTime(_surveyEvent?.startDateTimeUtc, format: dateFormat),
          defaultValue: defaultEmptyValue);
      String eventStartTime = StringUtils.ensureNotEmpty(AppDateTime().formatDateTime(_surveyEvent?.startDateTimeUtc, format: timeFormat),
          defaultValue: defaultEmptyValue);
      bool hasAccounts = CollectionUtils.isNotEmpty(accounts);
      List<List<dynamic>> rows = <List<dynamic>>[[
        'Survey Name',
        'Date Responded',
        'Time Responded',
      ]];
      if (StringUtils.isNotEmpty(widget.survey.calendarEventId)) {
        rows.first.addAll([
          'Event Name',
          'Event Start Date',
          'Event Start Time',
        ]);
      }
      rows.first.addAll([
        // 'UIN',
        // 'NetID',
        'First Name',
        'Last Name',
        if (!combineResponses)
          'Prompt',
        'Response'
      ]);

      for (SurveyResponse response in _surveyResponses!) {
        String? accountId = response.userId;
        Auth2Account? account =
            ((accountId != null) && hasAccounts) ? accounts!.firstWhereOrNull((account) => (account.id == accountId)) : null;
        Survey? survey = response.survey;
        if (survey != null) {
          List<String> answers = [];
          for (SurveyData? data = Surveys().getFirstQuestion(survey); data != null; data = Surveys().getFollowUp(survey, data)) {
            String question = data.text;
            String answer = data.response.toString();
            if (data is SurveyQuestionTrueFalse && data.style == 'yes_no') {
              bool? response = data.response as bool?;
              if (response != null) {
                answer = response ? 'Yes' : 'No';
              }
            }
            if (combineResponses)  {
              answers.add(answer);
            } else {
              rows.add([
                surveyName,
                StringUtils.ensureNotEmpty(AppDateTime().formatDateTime(response.dateTakenLocal, format: dateFormat),
                    defaultValue: defaultEmptyValue),
                StringUtils.ensureNotEmpty(AppDateTime().formatDateTime(response.dateTakenLocal, format: timeFormat),
                    defaultValue: defaultEmptyValue),
              ]);
              if (StringUtils.isNotEmpty(widget.survey.calendarEventId)) {
                rows.last.addAll([
                  eventName,
                  eventStartDate,
                  eventStartTime,
                ]);
              }
              rows.last.addAll([
                // StringUtils.ensureNotEmpty(account?.externalIds?.uin, defaultValue: defaultEmptyValue),
                // StringUtils.ensureNotEmpty(account?.externalIds?.netId, defaultValue: defaultEmptyValue),
                StringUtils.ensureNotEmpty(account?.profile?.firstName, defaultValue: defaultEmptyValue),
                StringUtils.ensureNotEmpty(account?.profile?.lastName, defaultValue: defaultEmptyValue),
                question,
                answer
              ]);
            }
          }
          
          if (combineResponses) {
            rows.add([
              surveyName,
              StringUtils.ensureNotEmpty(AppDateTime().formatDateTime(response.dateTakenLocal, format: dateFormat),
                  defaultValue: defaultEmptyValue),
              StringUtils.ensureNotEmpty(AppDateTime().formatDateTime(response.dateTakenLocal, format: timeFormat),
                  defaultValue: defaultEmptyValue),
            ]);
            if (StringUtils.isNotEmpty(widget.survey.calendarEventId)) {
              rows.last.addAll([
                eventName,
                eventStartDate,
                eventStartTime,
              ]);
            }
            rows.last.addAll([
              // StringUtils.ensureNotEmpty(account?.externalIds?.uin, defaultValue: defaultEmptyValue),
              // StringUtils.ensureNotEmpty(account?.externalIds?.netId, defaultValue: defaultEmptyValue),
              StringUtils.ensureNotEmpty(account?.profile?.firstName, defaultValue: defaultEmptyValue),
              StringUtils.ensureNotEmpty(account?.profile?.lastName, defaultValue: defaultEmptyValue),
              answers
            ]);
          }
        }
      }
      String? dateExported = AppDateTime().formatDateTime(DateTime.now(), format: 'yyyy-MM-dd-HH-mm');
      String fileName = '${surveyName.toLowerCase().replaceAll(" ", "_")}_results_$dateExported.csv';
      AppCsv.exportCsv(context: context, rows: rows, fileName: fileName).then((_) {
        AppToast.show('$surveyName results downloaded');
        setStateIfMounted(() {
          _decreaseLoadingProgress();
        });
      });
    });
  }

  void _loadSurveyResponses() {
    if (StringUtils.isNotEmpty(widget.survey.id) && !widget.survey.isSensitive) {
      setStateIfMounted(() {
        _increaseLoadingProgress();
      });
      Surveys().loadAllSurveyResponses(widget.survey.id).then((result) {
        List<SurveyResponse>? responses;
        if (result is String) {
          AppAlert.showDialogResult(context, result);
        } else if (result is List<SurveyResponse>) {
          responses = result;
        }
        setStateIfMounted(() {
          _surveyResponses = responses;
          _decreaseLoadingProgress();
        });
      });
    }
  }

  void _loadSurveyEvent() {
    String? eventId = widget.survey.calendarEventId;
    if (StringUtils.isNotEmpty(eventId)) {
      setStateIfMounted((){
        _increaseLoadingProgress();
      });
      Events2().loadEvent(eventId!).then((event){
        setStateIfMounted((){
          _surveyEvent = event;
          _decreaseLoadingProgress();
        });
      });
    }
  }

  void _increaseLoadingProgress() {
    _loadingProgress++;
  }

  void _decreaseLoadingProgress() {
    _loadingProgress--;
  }

  bool get _isLoading => (_loadingProgress > 0);

  Widget get _horizontalDivider =>
      Padding(padding: EdgeInsets.symmetric(vertical: 26), child: Container(height: 1, color: Styles().colors.dividerLine));
}
