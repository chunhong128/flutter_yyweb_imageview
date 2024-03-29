import 'package:flutter/material.dart';
import 'package:yyweb_imageview/yyweb_imageview.dart';



void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('yyweb_imageview'),
        ),
        body: Column(
          children: <Widget>[
            YYWebImageView('http://zonemin.bs2cdn.yy.com/3.0.gif'),
            YYWebImageView(
              'https://cn.bing.com/th?id=OHR.IchetuckneeRiver_ZH-CN1410417151_UHD.jpg&pid=hp',
              width: 240,
              height: 240,
              backgroundColor: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
