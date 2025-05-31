import 'package:flutter/material.dart';
import 'package:rokwire_plugin/model/group.dart';
import 'package:rokwire_plugin/model/poll.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:rokwire_plugin/service/groups.dart';
import 'package:rokwire_plugin/service/localization.dart';
import 'package:illinois/utils/AppUtils.dart';
import 'package:rokwire_plugin/service/polls.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:illinois/ui/polls/PollProgressPainter.dart';
import 'package:rokwire_plugin/utils/utils.dart';
import 'package:sprintf/sprintf.dart';
import 'package:illinois/service/Polls.dart' as illinois;

class PollCard extends StatefulWidget {
  final Poll poll;
  final Group? group;

  const PollCard({Key? key, required this.poll, this.group}) : super(key: key);
  _PollCardState createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  List<GlobalKey>? _progressKeys;
  double? _progressWidth;
  List<double>? _progressHeights;

  bool _showStartPollProgress = false;
  bool _showEndPollProgress = false;
  bool _showDeletePollProgress = false;

  GroupStats? _groupStats;

  @override
  void initState() {
    _loadGroupStats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evalProgressDimensions();
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
    });

    String pollVotesStatus = _pollVotesStatus;

    List<Widget> footerWidgets = [];

    String? pollStatus;
    if(_poll.status == PollStatus.created) {
      pollStatus = Localization().getStringEx("panel.polls_home.card.state.text.created","Polls created");
      if (_poll.isMine) {
        footerWidgets.add(_createStartPollButton());
        footerWidgets.add(Container(height:8));
      }
    } if (_poll.status == PollStatus.opened) {
      pollStatus = Localization().getStringEx("panel.polls_home.card.state.text.open","Polls open");
      if (_poll.canVote) {
        footerWidgets.add(_createVoteButton());
        footerWidgets.add(Container(height:8));
      }
      if (_poll.isMine) {
        footerWidgets.add(_createEndPollButton());
        footerWidgets.add(Container(height:8));
      }
    }
    else if (_poll.status == PollStatus.closed) {
      pollStatus =  Localization().getStringEx("panel.polls_home.card.state.text.closed","Polls closed");
    }

    String? groupName = widget.group?.title;

    bool canDeletePoll = _poll.isMine || (widget.group?.currentUserIsAdmin ?? false);

    String pin = sprintf(Localization().getStringEx('panel.polls_home.card.text.pin', 'Pin: %s'), [
      sprintf('%04i', [_poll.pinCode ?? 0])
    ]);

    Widget optionsWidget = ((_poll.status == PollStatus.opened) && (_poll.settings?.hideResultsUntilClosed ?? false)) ?
    Text(Localization().getStringEx("panel.poll_prompt.text.rule.detail.hide_result", "Results will not be shown until the poll ends."), style: Styles().textStyles.getTextStyle("widget.card.detail.small")) :
    Column(children: _buildCheckboxOptions(),);

    Widget bodyWidget = Padding(padding: EdgeInsets.all(16), child:
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Visibility(visible: (widget.group != null), child:
      Padding(padding: EdgeInsets.only(bottom: 10, right: canDeletePoll ? 24 : 0), child:
      Row(children: [
        Padding(padding: EdgeInsets.only(right: 3), child:
        Text(Localization().getStringEx('panel.polls_home.card.group.label', 'Group:'), style:Styles().textStyles.getTextStyle("widget.card.title.tiny")
        ),
        ),
        Expanded(child:
        Text(StringUtils.ensureNotEmpty(groupName), overflow: TextOverflow.ellipsis, style:Styles().textStyles.getTextStyle("widget.card.title.tiny.fat")
        ),
        ),
      ]),
      ),
      ),
      Semantics(excludeSemantics: true, label: "$pollStatus,$pollVotesStatus", child:
      Padding(padding: EdgeInsets.only(bottom: 12, right: (canDeletePoll && (widget.group == null)) ? 24 : 0), child:
      Row(children: <Widget>[
        Text(StringUtils.ensureNotEmpty(pollVotesStatus), style:Styles().textStyles.getTextStyle("widget.card.detail.tiny.fat")
        ),
        Text('  ', style:Styles().textStyles.getTextStyle("widget.card.detail.tiny")
        ),
        Expanded(child:
        Text(pollStatus ?? '', style:
        Styles().textStyles.getTextStyle("widget.card.detail.tiny"),
        ),
        ),
        Expanded(child: Container()),
        Text(pin, style: Styles().textStyles.getTextStyle("widget.card.detail.tiny.fat"),
        )
      ],),
      ),
      ),
      Row(children: <Widget>[
        Expanded(child: Container(),)
      ],),
      Padding(padding: EdgeInsets.symmetric(vertical: 0),child:
      Text(StringUtils.ensureNotEmpty(_poll.title), style:Styles().textStyles.getTextStyle("widget.card.title.medium.extra_fat"),
      ),
      ),
      Container(height:12),
      optionsWidget,
      Container(height:25),
      Column(children: footerWidgets,),
    ]),
    );

    Widget contentWidget = _poll.isMine ?
    Stack(children: <Widget>[
      bodyWidget,
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        _createDeletePollImageButton(),
      ],),
    ]) : bodyWidget;

    return Semantics(container: true, child:
    Column(children: <Widget>[
      Container(decoration: BoxDecoration(color: Styles().colors.surface, borderRadius: BorderRadius.circular(5)), child:
      contentWidget
      ),
    ],),
    );
  }

  List<Widget> _buildCheckboxOptions() {
    bool isClosed = (_poll.status == PollStatus.closed);

    List<Widget> result = [];
    _progressKeys = [];
    int totalVotesCount = (_poll.results?.totalVotes ?? 0);
    int optionsCount = (_poll.options?.length ?? 0);
    int maxValueIndex = -1;
    if (isClosed && (totalVotesCount > 0)) {
      maxValueIndex = 0;
      for (int optionIndex = 0; optionIndex < optionsCount; optionIndex++) {
        int? optionVotes = _poll.results![optionIndex];
        int? maxOptionVotes = _poll.results![maxValueIndex];
        if ((optionVotes != null) && (maxOptionVotes != null) && (optionVotes > maxOptionVotes)) {
          maxValueIndex = optionIndex;
        }
      }
    }

    for (int optionIndex = 0; optionIndex < optionsCount; optionIndex++) {
      bool useCustomColor = isClosed && maxValueIndex == optionIndex;
      String option = _poll.options![optionIndex];
      bool didVote = ((_poll.userVote != null) && (0 < (_poll.userVote![optionIndex] ?? 0)));
      String checkboxIconKey = didVote ? 'check-circle-filled' : 'check-circle-outline-gray';

      String? votesString;
      int? votesCount = (_poll.results != null) ? _poll.results![optionIndex] : null;
      double votesPercent = ((0 < totalVotesCount) && (votesCount != null)) ? (votesCount.toDouble() / totalVotesCount.toDouble() * 100.0) : 0.0;
      if ((votesCount == null) || (votesCount == 0)) {
        votesString = '';
      }
      else if (votesCount == 1) {
        votesString = Localization().getStringEx("panel.polls_home.card.text.one_vote","1 vote");
      }
      else {
        String? votes = Localization().getStringEx("panel.polls_home.card.text.votes","votes");
        votesString = '$votesCount $votes';
      }

      GlobalKey progressKey = GlobalKey();
      _progressKeys!.add(progressKey);

      String semanticsText = option +"\n "+  votesString +"," + votesPercent.toStringAsFixed(0) +"%";

      result.add(Padding(padding: EdgeInsets.only(top: (0 < result.length) ? 8 : 0), child:
      GestureDetector(
          child:
          Semantics(label: semanticsText, excludeSemantics: true, child:
          Row(children: <Widget>[
            Padding(padding: EdgeInsets.only(right: 10), child: Styles().images.getImage(checkboxIconKey, excludeFromSemantics: true)),
            Expanded(
                flex: 5,
                key: progressKey, child:
            Stack(alignment: Alignment.centerLeft, children: <Widget>[
              CustomPaint(painter: PollProgressPainter(backgroundColor: Styles().colors.surface, progressColor: useCustomColor ?Styles().colors.fillColorPrimary:Styles().colors.textBackground, progress: votesPercent / 100.0), child: Container(height:_progressHeights?[optionIndex] ?? 30, width: _progressWidth),),
              Container(/*height: 15+ 16*MediaQuery.of(context).textScaleFactor,*/ child:
              Padding(padding: EdgeInsets.only(left: 5), child:
              Row(children: <Widget>[
                Expanded( child:
                Padding( padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Text(option, style: useCustomColor? Styles().textStyles.getTextStyle("panel.polls.home.check.accent") : Styles().textStyles.getTextStyle("panel.polls.home.check")),)),
                //TBD Do we need this icon and is it the correct icon resource?  Erase if not needed
                /*Visibility( visible: didVote,
                          child: Padding(padding: EdgeInsets.only(right: 10), child: Styles().images.getImage('check-circle-outline-gray', excludeFromSemantics: true))
                        ),*/
              ],),)
              ),
            ],)
            ),
            Expanded(
              flex: 5,
              child: Padding(padding: EdgeInsets.only(left: 10), child: Text('$votesString (${votesPercent.toStringAsFixed(0)}%)', textAlign: TextAlign.right,style: Styles().textStyles.getTextStyle("panel.polls.home.card.percentage.title"),),),
            )
          ],)
          ))));
    }
    return result;
  }

  Widget _createStartPollButton(){
    return _createButton(Localization().getStringEx("panel.polls_home.card.button.title.start_poll","Start Poll"), _onStartPollTapped, loading: _showStartPollProgress);
  }
  Widget _createEndPollButton(){
    return _createButton(Localization().getStringEx("panel.polls_home.card.button.title.end_poll","End Poll"), _onEndPollTapped, loading: _showEndPollProgress);
  }
  Widget _createVoteButton(){
    return _createButton(Localization().getStringEx("panel.polls_home.card.button.title.vote","Vote"), _onVoteTapped);
  }

  Widget _createButton(String title, void Function()? onTap, {bool enabled=true, bool loading = false}){
    return Container(padding: EdgeInsets.symmetric(horizontal: 54,), child:
    Semantics(label: title, container: true, button: true, excludeSemantics: true, child:
    GestureDetector(onTap: onTap, child:
    Stack(children: <Widget>[
      Container(padding: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
        decoration: BoxDecoration(
          color: Styles().colors.surface,
          border: Border.all(color: enabled? Styles().colors.fillColorSecondary :Styles().colors.surfaceAccent, width: 2.0),
          borderRadius: BorderRadius.circular(24.0),
        ),
        child: Center(child:
        Text(title, style: Styles().textStyles.getTextStyle("panel.polls.home.card.button.create.title")
        ),
        ),
      ),
      Visibility(visible: loading, child:
      Container(padding: EdgeInsets.symmetric(vertical: 5), child:
      Align(alignment: Alignment.center, child:
      SizedBox(height: 24, width: 24, child:
      CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color?>(Styles().colors.fillColorPrimary),)
      ),
      ),
      ),
      ),
    ])
    ),
    ),
    );
  }

  Widget _createDeletePollImageButton() {
    String title = Localization().getStringEx("panel.polls_home.card.button.title.delete_poll","Delete Poll");
    return Semantics(label: title, container: true, button: true, excludeSemantics: true, child:
    GestureDetector(onTap: _onDeletePollTapped, child:
    Stack(children: [
      Padding(padding: EdgeInsets.all(12), child:
      Styles().images.getImage('trash', excludeFromSemantics: true),
      ),
      _showDeletePollProgress ? Padding(padding: EdgeInsets.all(9), child:
      SizedBox(height: 24, width: 24, child:
      CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color?>(Styles().colors.fillColorSecondary),)
      )) : Container(),
    ]),
    ),
    );
  }

  Future<bool?> promptDeletePoll() async {
    String message =  Localization().getStringEx('panel.polls_home.card.button.prompt.delete_poll', 'Delete \"{PollTitle}\" poll?').replaceAll('{PollTitle}', StringUtils.ensureNotEmpty(_poll.title));

    return await showDialog(context: context, builder: (BuildContext context) {
      return AlertDialog(
          content: Text(message),
          actions: <Widget>[
            TextButton(child: Text(Localization().getStringEx("dialog.yes.title", "Yes")),
                onPressed:(){
                  Analytics().logAlert(text: message, selection: "Yes");
                  Navigator.pop(context, true);
                }),
            TextButton(child: Text(Localization().getStringEx("dialog.no.title", "No")),
                onPressed:(){
                  Analytics().logAlert(text: message, selection: "No");
                  Navigator.pop(context, false);
                }),
          ]
      );
    });
  }

  void _loadGroupStats() {
    String? groupId = widget.group?.id;
    if (StringUtils.isNotEmpty(groupId)) {
      Groups().loadGroupStats(groupId!).then((stats) {
        setStateIfMounted(() {
          _groupStats = stats;
        });
      });
    }
  }

  void _onStartPollTapped(){
    if (_showStartPollProgress != true) {
      _setStartButtonProgress(true);
      Polls().open(_poll.pollId).then((result) => _setStartButtonProgress(false)).catchError((e){
        _setStartButtonProgress(false);
        AppAlert.showDialogResult(context, illinois.Polls.localizedErrorString(e));
      });
    }
  }

  void _onEndPollTapped() {
    if (_showEndPollProgress != true) {
      _setEndButtonProgress(true);
      Polls().close(_poll.pollId).then((result) {
        if (mounted) {
          AppSemantics.announceMessage(context, Localization().getStringEx('panel.polls_home.card.button.message.end_poll.success', 'Poll ended successfully'));
          _setEndButtonProgress(false);
        }
      }).catchError((e) {
        if (mounted) {
          AppAlert.showDialogResult(context, illinois.Polls.localizedErrorString(e));
          _setEndButtonProgress(false);
        }
      });
    }
  }

  void _onDeletePollTapped() {
    if (_showDeletePollProgress != true) {
      promptDeletePoll().then((bool? result){
        if (result == true) {
          _setDeleteButtonProgress(true);
          Polls().delete(_poll.pollId).then((result) {
            if (mounted) {
              AppSemantics.announceMessage(context, Localization().getStringEx('panel.polls_home.card.button.message.delete_poll.success', 'Poll deleted successfully'));
              _setDeleteButtonProgress(false);
            }
          }).catchError((e){
            _setDeleteButtonProgress(false);
            AppAlert.showDialogResult(context, illinois.Polls.localizedErrorString(e));
          });
        }
      });
    }
  }

  void _onVoteTapped(){
    Polls().presentPollVote(widget.poll);
  }

  void _evalProgressDimensions() {
    if (_progressKeys != null) {
      double progressWidth = -1.0;
      for (int i = 0; i < (_progressKeys?.length ?? 0); i++) {
        GlobalKey progressKey = _progressKeys![i];
        final RenderObject? progressRender = progressKey.currentContext?.findRenderObject();
        if ((progressRender is RenderBox) && progressRender.hasSize) {
          if ((0 < progressRender.size.width) && ((progressWidth < 0.0) || (progressRender.size.width < progressWidth))) {
            progressWidth = progressRender.size.width;
          }
          if (0 < progressRender.size.height) {
            _progressHeights ??= List.filled(_progressKeys?.length ?? 0, 30.0);
            _progressHeights?[i] = progressRender.size.height;
          }
        }
      }
      if (0 < progressWidth) {
        setStateIfMounted(() {
          _progressWidth = progressWidth;
        });
      }
    }
  }

  void _setStartButtonProgress(bool showProgress){
    setStateIfMounted(() {
      _showStartPollProgress = showProgress;
    });
  }
  void _setEndButtonProgress(bool showProgress){
    setStateIfMounted(() {
      _showEndPollProgress = showProgress;
    });
  }

  void _setDeleteButtonProgress(bool showProgress){
    setStateIfMounted(() {
      _showDeletePollProgress = showProgress;
    });
  }

  Poll get _poll => widget.poll;

  String get _pollVotesStatus {
    bool hasGroup = (widget.group != null);
    int votes = hasGroup ? _uniqueVotersCount : (_poll.results?.totalVotes ?? 0);

    String statusString;
    if (1 < votes) {
      statusString = sprintf(Localization().getStringEx('panel.poll_prompt.text.many_votes', '%s votes'), ['$votes']);
    } else if (0 < votes) {
      statusString = Localization().getStringEx('panel.poll_prompt.text.single_vote', '1 vote');
    } else {
      statusString = Localization().getStringEx('panel.poll_prompt.text.no_votes_yet', 'No votes yet');
    }

    if (hasGroup && (votes > 0)) {
      statusString += sprintf(' %s %d', [Localization().getStringEx('panel.polls_home.card.of.label', 'of'), _groupMembersCount]);
    }

    return statusString;
  }

  int get _uniqueVotersCount => _poll.uniqueVotersCount ?? 0;

  int get _groupMembersCount => _groupStats?.activeMembersCount ?? 0;
}