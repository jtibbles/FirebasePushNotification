import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'data/components/firebase/firebase_options.dart';  //this file removed from example as it contains important keys
import 'data/components/firebase/firebase_push_notification_service.dart';


//Firebase code required------

  //For Android - This listener does not occur in iOS
  //If the app is placed in the background, notifications can still be listened for. But the listener has to occur here
  // ignore: prefer_typing_uninitialized_variables
  var _bgListenerMessage;

  @pragma('vm:entry-point')
  Future<void>_firebaseMessagingBackgroundHandler(RemoteMessage message) async {

      print('DEBUG (_firebaseMessagingBackgroundHandler): received a message while in background. Storing message for viewing later');

      //If using other Firebase services in the background (eg. Firestore), make sure you call 'initializeApp' before using other Firebase services;
      //await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);       

      //We already have an "onMessageOpenedApp", which passes a message through to our notification system when the user clicks a notification in the system tray. 
      //This would occur AFTER this listener has already been reached, in which case this listener is usurped by the onMessageOpenedApp method, as we don't want to
      //see same message twice. Therefore, if a mesage is heard in this background listener, we save it as a local object, and iff the "onMessageOpenedApp" is triggered, 
      //this message object will be nullified.
      //When the app returns to the foreground (using the FGBG package, see firebase_push_notification_service), if the local object still has something, it will display it.
      _bgListenerMessage = message;
  }

//-----------------------------

Future<void> main() async{

  //Ensure project is initiliased (good to do this anyway, but necessary for Firebase)
  WidgetsFlutterBinding.ensureInitialized(); 

  //Firebase code required------

    //Wait for Firebase to initialise (passing through the data created in firebase_options)
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); 

    //init the background message handler (android only)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  //----------------------------- 
    
  runApp(const MyApp());
  
}

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }

}

class MyHomePage extends StatefulWidget {

  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  //Firebase code required------
    final PushNotificationService _notificationService = PushNotificationService();
  //----------------------------

  @override
  Widget build(BuildContext context) {

    //Firebase code required------
      _notificationService.linkToContext( context, _bgListenerMessage );
    //----------------------------

    return const Scaffold(      
      body: Center(
        child: Text(
              'Firebase PN Example',
            ),
        ),
    );
  }

}
