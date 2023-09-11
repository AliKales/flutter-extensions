import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hablo/core/firebase/f_auth.dart';
import 'package:hablo/core/models/m_ago.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

extension NumExtension on num {
  bool get isOdd => this % 1 == 0;
  bool get isEven => this % 2 == 0;

  double toDynamicHeight(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    return height * this;
  }

  double toDynamicWidth(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    return width * this;
  }

  double toPercent(num max) {
    return 100 * (this / max);
  }

  ///[zeroToOnePercent] = 0.0->1.0
  double get zeroToOnePercent {
    double result = toInt() * 0.01;
    if (result > 1.0) result = 1.0;
    return result;
  }

  bool isBetween(num start, num end) {
    return this >= start && this <= end;
  }
}

extension IntExtension on int {
  Duration get toDuration => Duration(milliseconds: this);

  int get plusOne => this + 1;
  int get minusOne => this - 1;

  ///[toRandom] generates a random number
  ///Ex: 1.toRandom(5) = 1,2,3,4
  int toRandom(int max) {
    return Random().nextInt(max) + this;
  }

  DateTime toDate() {
    return DateTime.fromMicrosecondsSinceEpoch(this);
  }

  DateTime get millisecsToDate {
    return DateTime.fromMillisecondsSinceEpoch(this);
  }
}

extension ContextExtension on BuildContext {
  double get width => MediaQuery.of(this).size.width;
  double get height => MediaQuery.of(this).size.height;

  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  Widget sizedBox({double height = 0, double width = 0}) {
    return SizedBox(
      height: height * this.height,
      width: width * this.width,
    );
  }

  void afterBuild(Function(Duration) afterBuild) {
    WidgetsBinding.instance.addPostFrameCallback(afterBuild);
  }

  T provider<T>() {
    return Provider.of<T>(this, listen: false);
  }

  T providerListen<T>() {
    return Provider.of<T>(this);
  }

  Future<T> navigatorPush<T>(page) async {
    MaterialPageRoute route = MaterialPageRoute(builder: (context) => page);
    var object = await Navigator.push(this, route);
    return object;
  }

  void navigatorPushReplacement(page) {
    MaterialPageRoute route = MaterialPageRoute(builder: (context) => page);
    Navigator.pushReplacement(this, route);
  }

  RelativeRect get toRelativeRec {
    //*get the render box from the context
    final RenderBox renderBox = findRenderObject() as RenderBox;
    //*get the global position, from the widget local position
    final offset = renderBox.localToGlobal(Offset.zero);

    //*calculate the start point in this case, below the button
    final left = offset.dx;
    final top = offset.dy + renderBox.size.height;
    //*The right does not indicates the width
    final right = left + renderBox.size.width;

    return RelativeRect.fromLTRB(left, top, right, 0.0);
  }
}

extension WidgetExtension on Widget {
  Widget? toVisible(bool isVisible) {
    if (isVisible) return null;

    return this;
  }

  Widget toEmpty(bool isVisible) {
    if (isVisible) return const SizedBox.shrink();

    return this;
  }

  Widget loading(bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return this;
  }

  Widget get center => Center(
        child: this,
      );

  Widget get centerAlign => Align(
        alignment: Alignment.center,
        child: this,
      );

  Widget get left => Align(
        alignment: Alignment.centerLeft,
        child: this,
      );

  Widget get right => Align(
        alignment: Alignment.centerRight,
        child: this,
      );

  Widget get centerColumn => Column(
        children: [
          const Spacer(),
          this,
          const Spacer(),
        ],
      );
  Widget get centerRow => Row(
        children: [
          const Spacer(),
          this,
          const Spacer(),
        ],
      );

  Widget backButton(BuildContext context, [Future<bool> Function()? onBack]) {
    return WillPopScope(
        onWillPop: onBack ??
            () async {
              context.pop();

              return false;
            },
        child: this);
  }
}

extension MapExtension on Map? {
  Map? handleDates() {
    if (this == null) return this;
    var dateKeys = this!
        .keys
        .where((element) => element.toString().contains("At"))
        .toList();

    for (var dataKey in dateKeys) {
      var data = this![dataKey];

      if (data != null && data is int) {
        this![dataKey] = data.toDate().toIso8601String();
      } else if (data != null) {
        this![dataKey] = (data as Timestamp).toDate().toIso8601String();
      } else {
        this![dataKey] = DateTime.now().toIso8601String();
      }
    }

    return this;
  }

  Map? handleDatesForDB(List<String> keys, bool isCloudDB) {
    for (var element in keys) {
      if (isCloudDB) {
        this![element] = FieldValue.serverTimestamp();
      } else {
        this![element] = ServerValue.timestamp;
      }
    }
    return this;
  }

  Object removeAndGet(Object key) {
    var value = this![key];
    this!.remove(key);
    return value;
  }
}

extension TextExtension on Text {
  Widget get toBoldWhite {
    return Text(
      data ?? "",
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  Widget toBold([Color? color]) {
    return Text(
      data ?? "",
      style:
          TextStyle(fontWeight: FontWeight.bold, color: color ?? Colors.white),
    );
  }
}

extension FunctionExtension on Function {
  ///[name] returns name of function
  String get name {
    if (kIsWeb) {
      int firstCha = toString().indexOf("from: ") + 6;
      int secondCha = toString().indexOf("(", firstCha);

      return toString().substring(firstCha, secondCha);
    } else {
      int firstCha = toString().indexOf("'") + 1;
      int secondCha = toString().indexOf("':");

      return toString().substring(firstCha, secondCha);
    }
  }

  ///[path] example: /page
  String get path {
    return "/$name";
  }
}

extension TextStyleExtension on TextStyle {
  TextStyle get toBold {
    return copyWith(fontWeight: FontWeight.bold);
  }

  TextStyle get toWhite {
    return copyWith(color: Colors.white);
  }

  TextStyle get toBlack {
    return copyWith(color: const Color(0xFF313644));
  }
}

extension ListExtensionNull<E> on List<E>? {
  int indexWhereNull(bool Function(E) test, [int start = 0]) {
    if (this == null) return -1;

    return this!.indexWhere(test, start);
  }
}

extension ListExtension<E> on List<E> {
  int get count => length - 1;

  E? get firstOrNull => (isEmpty) ? null : first;

  List<E> sublistSafe(int start, [int? end]) {
    if (isEmpty) return [];
    if (end != null && end > this.count) {
      end = length;
    }
    return sublist(start, end);
  }
}

extension StringExtension on String? {
  String get lastLetter {
    if (this == null || this!.isEmpty) {
      return '';
    } else {
      return this!.substring(this!.length - 1);
    }
  }

  String get fileType => this?.split(".").last ?? "";

  String get shuffled => String.fromCharCodes(this!.runes.toList()..shuffle());

  Uri get uriParse => Uri.parse(this ?? "");

  int get toInt {
    return int.tryParse(this ?? "") ?? 0;
  }

  double get toDouble {
    return double.tryParse(this ?? "") ?? 0;
  }

  String get toStringFromDate {
    DateTime? dateTime = DateTime.tryParse(this ?? "");

    if (dateTime == null) return "";

    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }

  String capitalize() {
    if (this == null) return "";
    return "${this![0].toUpperCase()}${this!.substring(1)}";
  }

  // String localize(Map<String, String> supplants) {
  //   if (this == null) return "error";
  //   return StringUtils.supplant(this!, supplants);
  // }

  String get removeLast {
    if (isEmptyOrNull) return "";
    return this!.substring(0, this!.length - 1);
  }

  DateTime? get toDateTime {
    return DateTime.tryParse(this ?? "");
  }

  bool get checkIfNull {
    return this == null || this!.toLowerCase() == "null";
  }

  bool get isNotEmptyAndNull {
    return this != null && this!.trim() != "";
  }

  bool get isEmptyOrNull {
    return this == null || this?.trim() == "";
  }

  bool get toBool {
    if ((this?.toLowerCase() ?? "true") == "true") {
      return true;
    } else {
      return false;
    }
  }

  String? get toStringg {
    if (this == "null") {
      return null;
    }

    return this;
  }
}

extension DateTimeExtension on DateTime {
  MAgo get ago {
    Duration d = DateTime.now().difference(this);

    if (d.inSeconds < 60) {
      return MAgo(d.inSeconds, "second");
    } else if (d.inMinutes < 60) {
      return MAgo(d.inMinutes, "minute");
    } else if (d.inHours < 24) {
      return MAgo(d.inHours, "hour");
    } else if (d.inDays == 1) {
      return MAgo(0, "yesterday");
    } else if (d.inDays < 30) {
      return MAgo(d.inDays, "day");
    } else if (d.inDays < 365) {
      return MAgo((d.inDays / 30).floor(), "month");
    } else {
      return MAgo((d.inDays / 365).floor(), "year");
    }
  }

  String get hhMM {
    return toString().substring(11, 16);
  }

  String get hh {
    return toString().substring(11, 13);
  }

  String get mm {
    return toString().substring(14, 16);
  }

  String get toStringFromDate {
    return "$day/$month/$year";
  }

  DateTime get toLocalDate {
    var now = DateTime.now();
    return add(now.timeZoneOffset);
  }

  String get toId {
    DateTime future = DateTime(3000).toUtc();
    Duration duration = future.difference(DateTime.now().toUtc());
    return duration.inMilliseconds.toString() + FAuth.getUid!.substring(0, 5);
  }
}

extension ScrollControllerExtension on ScrollController {
  double get max {
    return position.maxScrollExtent;
  }
}

extension TextEditingExtension on TextEditingController {
  String get textTrim {
    return text.trim();
  }

  bool get isEmpty {
    return text.trim() == "";
  }
}

extension BoolExtension on bool? {
  bool get isFalse {
    if (this == null) return false;

    return this == false;
  }

  bool get isTrue {
    if (this == null) return false;

    return this == true;
  }
}

extension ColorExtension on Color {
  Color toTransparent(bool isTrue) => isTrue ? Colors.transparent : this;
}

extension GoRouterExtension on GoRouter {
  String get location {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    final String location = matchList.uri.toString();

    return location;
  }
}

extension FileExtension on File {
  String get name => path.split("/").last;
}

extension ProductDetailsExtension on ProductDetails {
  String get titleOnly => title.replaceAll("(Hablo Talk)", "").trim();

  int get month => description.split("-").first.toInt;
}
