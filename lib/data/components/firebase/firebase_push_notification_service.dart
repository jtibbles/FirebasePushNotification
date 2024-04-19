// ignore_for_file: non_constant_identifier_names, prefer_typing_uninitialized_variables

/* Firebase Push Notification Service: 
  This file initilaizes Firebase Cloud Messaging and provides the following functions:
  1) Get the device token (and detect token changes, which currently does nothing)
  2) Listen for incoming notifications when app in foreground.
  3) Listen for system tray notification click-throughs
  4) (android only) Listen for incoming notifications when app is in background, displaying message when app returns to foreground (if notificatio click-through didn't occur)
  5) Optional badge count handling, if required (more work required per project for this)
*/

import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';


class PushNotificationService {
  
  final FirebaseMessaging _fbm = FirebaseMessaging.instance;  
  late final NotificationSettings _fbm_settings;
  late String? _token;
  late BuildContext _context;
  late var _bgListenerMessage;
  bool canUseBadge = false;

  PushNotificationService(){
    initialize();
  }


  //Connect GUI so that we know where to display popup box. Also pass through a pointer to a backgroundmessage value that may or may not contain data
  //This method is called from the main.dart Build function
  void linkToContext(BuildContext context, bgListenerMessage){
    _context = context;
    _bgListenerMessage = bgListenerMessage;
  }


  //Initialize all our listeners and handlers
  Future initialize() async {

    //For Apple platforms, ensure the APNS token is available before making any PCM plugin API calls
    if( Platform.isIOS ){
      final apnsToken = await _fbm.getAPNSToken();
      if( apnsToken != null){
        // APNS token is available, make FCM plugin API requests...
      }
    }

    //Request Permission
    //("Provisional = true" allows the user to choose what type of notifications they would like to receive once the user receive a notification)
    _fbm_settings = await _fbm.requestPermission(
        alert: true,
         announcement: false,
         badge: true,
         criticalAlert: false,
         provisional: false,
         sound: true,
    );

    //Once permission is granted, continue to initialize our listeners, handlers etc
    if(_fbm_settings.authorizationStatus == AuthorizationStatus.authorized){
      
      //Init the other functions
      getTheToken(); //optional, if you want to do something with token
      initTokenRefresher(); //optional, currently doesn't do anything
      initForegroundListener();
      initOpenedAppListener();
      initInteractedMessage();
      initFgBg(); //for android only

      //Can this platform use badge count?
      try {
        canUseBadge = await FlutterAppBadger.isAppBadgeSupported();
      } on PlatformException {
        canUseBadge = false;
      }
    }
    
  } 
  

  // Get the token
  void getTheToken() async{    
    _token = await _fbm.getToken();
    print('token = $_token');
  }
  

  //listen for token refreshing - currently doesn't do anything other than print a message
  void initTokenRefresher(){
    _fbm.onTokenRefresh.listen((fcmToken){
    print("DEBUG (onTokenRefresh): token was refreshed...nothing doing");
      //fcmToken.toString() will be the String of the new token
      // TO DO: If necessary send token to application server.
      // Note: This callback is called at each app startup and whenever a new token is generated
    })
    .onError((err){
      //Error getting token
    });
  }


  //If app is in foreground, listen for messages directly
  void initForegroundListener(){
    FirebaseMessaging.onMessage.listen((RemoteMessage message){
     print("DEBUG (onMessage): notification detected via foreground onMEssage listener");
    _handleMessage(message);
    });
  }  


  //If the app has been opened from a background state via a [RemoteMessage] (containing a [Notification]), display message.
  void initOpenedAppListener(){
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
     print("DEBUG (onMessageOpenedApp): app opened via user click from system tray notification popup");
    _handleMessage(message);
    });
  }

  //If the app has been opened from a terminated state via a [RemoteMessage] (containing a [Notification]), display message.
  Future<void> initInteractedMessage() async {

    print("DEBUG (initInteractedMessage): checking for initial message...");
    //Get any messages which caused the application to open from a terminated state
    RemoteMessage? interactedMessage = await _fbm.getInitialMessage();

    //send initial message to handler
    if (interactedMessage != null){

      //remove the _bgListenerMessage message as it has now been usurped by the interacted message, and so never needs to be shown.
      _bgListenerMessage = null;

      //display the interacted message
      _handleMessage(interactedMessage);
    }

  }


  //FOR ANDROID ONLY, iOS background message notification handlers only work directly through the notification click handling.
  //If a "_bgListenerMessage" value exists (android only), then main.dart received a message while app was in BG (android only). 
  //Once app returns to foreground, if actioned without the system tray notification click-through, we still need to display the message.
  void initFgBg(){

      FGBGEvents.stream.listen((event){

        //Detected that app returned to foreground...
        if(event == FGBGType.foreground){
    
         print("DEBUG (FGBGEvents): app has been placed back to the foreground...");

          //Give "setupInteractedMessage" function time to run first (so delay the rest of this function by 0.5 seconds)
          Timer(
            const Duration(milliseconds: 500),
            (){

              print("DEBUG (FGBGEvents): after 0.5 second wait, looking for _bgListenerMessage...");

              //If a background message exists (a messaage retrieved by background listener whilst app was in the backgound)
              if(null != _bgListenerMessage) {

                //...display the message
                _handleMessage(_bgListenerMessage);
                
                //...wipe the mesage as soon as it's shown
                _bgListenerMessage = null;
              }
            }

          );
        }
      });
  }
  

  //Handle/Display message on screen
  Future<void> _handleMessage(RemoteMessage message) async{

      //Create new messagecontent object
      Map messagecontent = {};

      //Badger stuff (optional)
      if(canUseBadge) FlutterAppBadger.updateBadgeCount(1);


      //This notification type will be displayed in the system tray (if app is in the background)
      //Once app returns to foreground, HOw we display the message depnds on us (the project)...

      if (message.notification != null) {
        print('Message contained a notification:');
        print(message.notification?.title);
        print(message.notification?.body);

        //Set our popup title and body to match the values of the notification title and body
        messagecontent['title'] = (null != message.notification?.title) ? message.notification?.title : '';
        messagecontent['body'] = (null != message.notification?.body) ? message.notification?.body : '';
        
      }

      //Data notifications have an array with unlimited key/value pairs. So it's important to know beforehand, what variables need to be used
      //In this example, "datatitle" and "databody" parameters are allowed, and replace the title / body content.
      if (message.data.isNotEmpty){        
        print('Message contained additional data:');
        print(message.data["datatitle"]);
        print(message.data["databody"]);

        //Replace in-app message title with the "datatitle"
        if(null != message.data["datatitle"]){
          messagecontent['title'] = message.data["datatitle"];
        }
        //Replace in-app message body with the "databody"
        if(null != message.data["databody"]){
          messagecontent['body'] = message.data["databody"];
        }
      }

      //Create the message Popup window
      return showDialog<void>(
        context: _context,
        barrierDismissible: false,
        builder: (BuildContext context){
          return AlertDialog(
            title: Text(messagecontent['title']),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  Text(messagecontent['body']),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: (){
                  if(canUseBadge) FlutterAppBadger.removeBadge();
                  Navigator.of(context).pop();
                }
              ),
            ]

          );
        }
      );

  }

}
