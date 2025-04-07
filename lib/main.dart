import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

class AppInitialization extends StatefulWidget {
  @override
  _AppInitializationState createState() => _AppInitializationState();
}

class _AppInitializationState extends State<AppInitialization> {
  String? iosSystemVersion;
  String? deviceType;
  String? appsFlyerUniqueId;
  String? firebaseCloudMessagingToken;
  late AppsflyerSdk appsFlyerInstance;
  String adIdentifier = "Fetching Advertising Identifier...";
  String trackingPermission = "Unknown";
  String? serverResponse = "No response";
  String queryString = "";

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // FCM Token listener
    NotificationTokenListener.listenForUpdates((token) {
      setState(() {
        firebaseCloudMessagingToken = token;
      });
    });

    initializeApplication();

    // Send GET request after a delay
    Future.delayed(const Duration(seconds: 3)).then((_) {
      fetchDataFromServer();
    });

    // Navigate to the game screen
    Future.delayed(const Duration(seconds: 7)).then((_) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => GameScreen(queryString)),
      );
    });
  }

  Future<void> initializeApplication() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    await requestNotificationPermissions();
    initializeAppsFlyer();
    await fetchDeviceInfo();
    await fetchFirebaseToken();
  }

  Future<void> requestNotificationPermissions() async {
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("User granted notification permission.");
    } else {
      print("User denied notification permission.");
    }
  }

  void initializeAppsFlyer() {
    AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: "P8Cmc5f5JjkNjQ3haoGbWS",
      appId: "",
      showDebug: true,
    );

    appsFlyerInstance = AppsflyerSdk(options);

    appsFlyerInstance.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    appsFlyerInstance.startSDK(
      onSuccess: () {
        print("AppsFlyer SDK initialized successfully.");
      },
      onError: (int errorCode, String errorMessage) {
        print("AppsFlyer SDK initialization error: $errorCode - $errorMessage");
      },
    );
  }

  Future<void> fetchDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final iosInfo = await deviceInfoPlugin.iosInfo;

    setState(() {
      iosSystemVersion = iosInfo.systemVersion;
      deviceType = iosInfo.utsname.machine;
    });
  }

  Future<void> fetchFirebaseToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      setState(() {
        firebaseCloudMessagingToken = token;
      });
      print("Firebase Token: $firebaseCloudMessagingToken");
    } catch (e) {
      print("Error fetching Firebase token: $e");
    }
  }

  Future<void> fetchDataFromServer() async {
    appsFlyerUniqueId = await appsFlyerInstance.getAppsFlyerUID();
    final deviceInfo = DeviceInfoPlugin();
    final iosInfo = await deviceInfo.iosInfo;

    String? language = 'rus';
    String? timezone = DateTime.now().timeZoneName;
    String? deviceId = iosInfo.identifierForVendor;

    setState(() {
      queryString =
      "device_model=${iosInfo.utsname.machine}"
          "&os_version=${iosInfo.systemVersion}"
          "&fcm_token=${firebaseCloudMessagingToken ?? ""}"
          "&language=$language"
          "&timezone=$timezone"
          "&apps_flyer_id=$appsFlyerUniqueId"
          "&device_id=$deviceId";
    });

    String fullUrl = "https://genders-joker.online/gj-ios/v4qojivq/index.php?$queryString";
    print("Fetching URL: $fullUrl");

    try {
      final response = await http.get(Uri.parse(fullUrl));

      if (response.statusCode == 200) {
        setState(() {
          serverResponse = "Success: ${response.body}";
        });
      } else {
        setState(() {
          serverResponse = "Error: ${response.statusCode} - ${response.reasonPhrase}";
        });
      }
    } catch (e) {
      setState(() {
        serverResponse = "Request failed: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AppInitialization(),
  ));
}

class NotificationTokenListener {
  static const MethodChannel _channel = MethodChannel('com.example.fcm/token');

  static void listenForUpdates(Function(String token) onTokenUpdated) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'setToken') {
        final String token = call.arguments as String;
        onTokenUpdated(token);
        print('FCM Token received in Flutter: $token');
      }
    });
  }
}

class GameScreen extends StatefulWidget {
  final String queryParameters;
  GameScreen(this.queryParameters);

  @override
  _GameScreenState createState() => _GameScreenState(queryParameters);
}

class _GameScreenState extends State<GameScreen> {
  final String queryParameters;
  _GameScreenState(this.queryParameters);

  late InAppWebViewController webViewController;
  bool isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri("https://genders-joker.online/gj-ios/")),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                isLoading = true;
              });
            },
            onLoadStop: (controller, url) {
              setState(() {
                isLoading = false;
              });
            },
          ),
          if (isLoading)
            Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}