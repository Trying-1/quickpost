import 'package:flutter/material.dart';

class AdBannerWidget extends StatefulWidget {
  final String screenName;
  
  const AdBannerWidget({
    Key? key,
    required this.screenName,
  }) : super(key: key);
  
  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
