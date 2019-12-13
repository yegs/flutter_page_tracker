import 'package:flutter/material.dart';
import 'dart:async';

import 'tracker_page_mixin.dart';
import 'page_tracker_aware.dart';

enum PageTrackerEvent {PageView, PageExit}

class PageViewWrapper extends StatefulWidget {

  final int pageAmount;
  final int initialPage;
  final Widget child;
  final ChangeDelegate changeDelegate;

  const PageViewWrapper({
    Key key,
    this.pageAmount = 0,
    this.initialPage = 0,
    this.child,
    this.changeDelegate,
  }):
        assert(pageAmount != null),
        super(key: key);

  @override
  PageViewWrapperState createState() {

    return PageViewWrapperState();
  }

  static Stream<PageTrackerEvent> of(BuildContext context, int index) {
    assert(index >= 0);
    List<Stream<PageTrackerEvent>> broadCaseStreams = (context.ancestorStateOfType(TypeMatcher<PageViewWrapperState>()) as PageViewWrapperState).broadCaseStreams;
    assert(index < broadCaseStreams.length);

    return broadCaseStreams[index];
  }
}

class PageViewWrapperState extends State<PageViewWrapper> with PageTrackerAware, TrackerPageMixin {

  List<StreamController<PageTrackerEvent>> controllers = [];
  List<Stream<PageTrackerEvent>> broadCaseStreams = [];
  // 上一次打开的Page
  int currPageIndex;
  // 监听子页面控制器
  StreamSubscription<int> pageChangeSB;

  @override
  void initState() {
    super.initState();

    currPageIndex = widget.initialPage;

    // 创建streams
    controllers = List(widget.pageAmount);
    for(int i=0; i<controllers.length; i++) {
      controllers[i] = StreamController<PageTrackerEvent>();
    }

    broadCaseStreams = controllers.map((controller) {
      return controller.stream.asBroadcastStream();
    }).toList();

    // 发送首次PageView事件
    controllers[currPageIndex].sink.add(PageTrackerEvent.PageView);

    // 发送后续Page事件
    widget.changeDelegate.listen();
    pageChangeSB = widget.changeDelegate.stream.listen(_onPageChange);
  }

  void _onPageChange(int index) {

    if (currPageIndex == index) {
      return;
    }

    // 发送PageExit
    if (currPageIndex != null) {
      controllers[currPageIndex].sink.add(PageTrackerEvent.PageExit);
    }

    currPageIndex = index;

    // 发送PageView
    controllers[currPageIndex].sink.add(PageTrackerEvent.PageView);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void didPageView() {
    super.didPageView();
    controllers[currPageIndex].sink.add(PageTrackerEvent.PageView);
  }

  @override
  void didPageExit() {
    super.didPageExit();
    // 发送tab中的page离开
    controllers[currPageIndex].sink.add(PageTrackerEvent.PageExit);
  }

  @override
  void dispose() {
    pageChangeSB?.cancel();
    widget.changeDelegate.dispose();
    super.dispose();
  }

}

abstract class ChangeDelegate {
  StreamController<int> streamController;
  Stream<int> stream;

  ChangeDelegate() {
    streamController = StreamController<int>();
    stream = streamController.stream.asBroadcastStream();
  }

  void sendPageChange(int index) {
    streamController.sink.add(index);
  }

  @protected
  void listen();

  @protected
  void onChange();

  @protected
  void dispose() {
    streamController?.close();
  }
}

class PageViewChangeDelegate extends ChangeDelegate {

  PageController pageController;

  PageViewChangeDelegate(this.pageController): super();

  @override
  void listen() {
    pageController.addListener(onChange);
  }

  @override
  void onChange() {
    if (0 != pageController.page % 1.0) {
      return;
    }

    sendPageChange(pageController.page.toInt());
  }

  @override
  void dispose() {
    pageController.removeListener(onChange);
    super.dispose();
  }
}