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

import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart' as htmlParser;
import 'package:html/dom.dart' as dom;
import 'package:illinois/service/AppDateTime.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:rokwire_plugin/utils/utils.dart';
import 'package:xml/xml.dart';

class DailyIlliniItem {
  final String? title;
  final String? link;
  final String? description;
  final String? thumbImageUrl;
  final String? category;
  final DateTime? pubDateTimeUtc;
  // final String? summary;

  DailyIlliniItem({this.title, this.link, this.description, this.thumbImageUrl, this.pubDateTimeUtc, this.category});

  String? get displayPubDate {
    DateTime? localDateTime = AppDateTime().getDeviceTimeFromUtcTime(pubDateTimeUtc);
    return AppDateTime().formatDateTime(localDateTime, format: 'LLLL d, yyyy', ignoreTimeZone: true);
  }

  static DailyIlliniItem? fromXml(XmlElement? xml) {
    if (xml == null) {
      return null;
    }
    String? pubDateString = XmlUtils.childText(xml, 'pubDate');
    String? descriptionString = XmlUtils.childCdata(xml, 'description');
    String? categoryString = _getCategory(xml.toString());
    // String? summary = _getSummary(descriptionString);
    String? thumbImgUrl = _getThumbImageUrl(descriptionString);
    // debugPrint('summary:  $summary');
    return DailyIlliniItem(
      title: XmlUtils.childText(xml, 'title'),
      link: XmlUtils.childText(xml, 'link'),
      category: categoryString,
      description: descriptionString,
      thumbImageUrl: thumbImgUrl,
      // summary: summary,
      // DateTime format:
      // Tue, 09 Aug 2022 12:00:17 +0000
      pubDateTimeUtc: DateTimeUtils.dateTimeFromString(pubDateString, format: "E, dd LLL yyyy hh:mm:ss Z", isUtc: true),
    );
  }

  static List<DailyIlliniItem>? listFromXml(Iterable<XmlElement>? xmlList) {
    List<DailyIlliniItem>? resultList;
    if (xmlList != null) {
      resultList = <DailyIlliniItem>[];
      for (XmlElement xml in xmlList) {
        ListUtils.add(resultList, DailyIlliniItem.fromXml(xml));
      }
    }
    return resultList;
  }

  ///
  /// Loops through <description> xml tag to find the correct image url for the Daily Illini item
  ///
  static String? _getThumbImageUrl(String? descriptionText) {
    if (StringUtils.isEmpty(descriptionText)) {
      debugPrint('Description is null');
      return null;
    }
    dom.Document document = htmlParser.parse(descriptionText);
    List<dom.Element> imgHtmlElements = document.getElementsByTagName('img');
    if (CollectionUtils.isNotEmpty(imgHtmlElements)) {
      dom.Element? secondImgElement = (imgHtmlElements.length >= 1) ? imgHtmlElements[0] : null;
      if (secondImgElement != null) {
        LinkedHashMap<Object, String> imgAttributes = secondImgElement.attributes;
        if (imgAttributes.isNotEmpty) {
          String? srcSetValue = imgAttributes['srcset'];
          if (StringUtils.isNotEmpty(srcSetValue)) {
            List<String>? srcSetValues = srcSetValue!.split(', ');
            if (CollectionUtils.isNotEmpty(srcSetValues)) {
              final String img475SizeTag = ' 475w';
              for (String srcValue in srcSetValues) {
                if (srcValue.endsWith(img475SizeTag)) {
                  return srcValue.substring(0, (srcValue.length - img475SizeTag.length));
                }
              }
              // return first src set value by default
              return srcSetValues.first.split(' ').first;
            } else {
              debugPrint('ImageLoad: srcSetValues is empty');
            }
          } else {
            debugPrint('ImageLoad: srcSetValue is empty');
          }
        } else {
          debugPrint('ImageLoad: imgAttributes is empty');
        }
      } else {
        debugPrint('ImageLoad: second image element is null');
      }
    } else {
      debugPrint('ImageLoad: cannot get img element tag');
    }
    return null;
  }
  static String? _getSummary(String? descriptionText) {
    dom.Document doc = htmlParser.parse(descriptionText);
    List<dom.Element> elements = doc.getElementsByTagName('p');
    String summary = "";
    for(dom.Element i in elements) {
      if (i.innerHtml.contains("...")) {
        summary = i.innerHtml;
      }
    }

    return summary.substring(0, summary.indexOf("."));
    int? i = descriptionText?.indexOf("<p>");
    int? j = descriptionText?.indexOf("...");

    return descriptionText?.substring(i! + 3, j! + 3);
  }
  static String? _getCategory(String? itemText) {
    dom.Document doc = htmlParser.parse(itemText);
    List<dom.Element> catElements = doc.getElementsByTagName('category');
    for (int i = 0; i < catElements.length; i++) {
      if (catElements[i].innerHtml.contains("Opinions")) {
        return "Opinions";
      } else if (catElements[i].innerHtml.contains("buzz")) {
        return "buzz";
      } else if (catElements[i].innerHtml.contains("Sports")) {
        return "Sports";
      } else if (catElements[i].innerHtml.contains("News")) {
        return "News";
      }
    }
    return "N/A";
  }
  List<DailyIlliniItem>? search(List<DailyIlliniItem> list, String cat) {
    // TODO: implement search
    List<DailyIlliniItem>? returnList;
    for (DailyIlliniItem iter in list) {
      if (iter.category != null) {
        String c = iter.category.toString();
        if (c.contains(cat)) {
          returnList?.add(iter);
        }
      }
    }
    return returnList;
  }
}
