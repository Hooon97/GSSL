import 'dart:async';

import 'package:GSSL/api/api_walk.dart';
import 'package:GSSL/components/walk/walk_length.dart';
import 'package:GSSL/components/walk/walk_timer.dart';
import 'package:GSSL/constants.dart';
import 'package:GSSL/model/request_models/put_walk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakaomap_webview/kakaomap_webview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:webview_flutter/webview_flutter.dart';

final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
List<Position> positionList = [];
StreamSubscription<Position>? _positionStreamSubscription;
int totalWalkLength = 0;

void main() async {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.black, // navigation bar color
    // statusBarColor: pColor, // status bar color
  ));

  WidgetsFlutterBinding.ensureInitialized();
  Position pos = await _determinePosition();
  await dotenv.load(fileName: ".env");
  String kakaoMapKey = dotenv.get('kakaoMapAPIKey');
  runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: KakaoMapTest(pos.latitude, pos.longitude, kakaoMapKey)));
}

class KakaoMapTest extends StatefulWidget {
  final double initLat;
  final double initLng;
  final String kakaoMapKey;

  const KakaoMapTest(this.initLat, this.initLng, this.kakaoMapKey);

  @override
  State<KakaoMapTest> createState() => _KakaoMapTestState();
}

class _KakaoMapTestState extends State<KakaoMapTest> {
  late ScreenshotController screenshotController = ScreenshotController();
  late WebViewController _mapController;
  late StopWatchTimer _stopWatchTimer =
      StopWatchTimer(mode: StopWatchMode.countUp);
  bool pressWalkBtn = false;
  DateTime startTime = DateTime.now();
  DateTime endTime = DateTime.now();
  String addrName = "";

  Timer? timer;

  void initTimer() {
    if (timer != null && timer!.isActive) return;

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      //job
      setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    initTimer();
    Size size = MediaQuery.of(context).size;
    // var appBarHeight = AppBar().preferredSize.height;
    // debugPrint(widget.initLat.toString());
    // debugPrint(widget.initLng.toString());

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight: 0,
      ),
      body: Container(
        child: SnappingSheet(
          // 슬라이드 모달창
          snappingPositions: [
            SnappingPosition.factor(
              positionFactor: 0,
              snappingCurve: Curves.easeOutExpo,
              snappingDuration: Duration(seconds: 1),
              grabbingContentOffset: GrabbingContentOffset.top,
            ),
            SnappingPosition.pixels(
              // 원하는 높이만큼 보임
              positionPixels: 150,
              snappingCurve: Curves.elasticOut,
              snappingDuration: Duration(milliseconds: 1750),
            ),
          ],
          lockOverflowDrag: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Screenshot(
                controller: screenshotController,
                child: Container(
                  child: KakaoMapView(
                    width: size.width,
                    // height: size.height * 7 / 10,
                    // height: size.height - appBarHeight - 130,
                    height: size.height - 100,
                    kakaoMapKey: widget.kakaoMapKey,
                    lat: widget.initLat,
                    lng: widget.initLng,
                    // zoomLevel: 1,
                    showMapTypeControl: false,
                    showZoomControl: false,
                    draggableMarker: false,
                    // mapType: MapType.TERRAIN,
                    mapController: (controller) {
                      _mapController = controller;
                    },
                    polyline: KakaoFigure(path: []),
                  ),
                ),
              ),
            ],
          ),
          grabbingHeight: 25,
          grabbing: Container(
              decoration: new BoxDecoration(
                color: pColor,
                borderRadius: new BorderRadius.only(
                  topLeft: const Radius.circular(25.0),
                  topRight: const Radius.circular(25.0),
                ),
              ),
              child: Container(
                margin: EdgeInsets.fromLTRB(150, 10, 150, 10),
                decoration: new BoxDecoration(
                  color: btnColor,
                  borderRadius: BorderRadius.all(Radius.circular(25)),
                ),
              )),
          sheetBelow: SnappingSheetContent(
            draggable: true,
            child: Container(
              color: pColor,
              child: Row(
                children: [
                  WalkTimer(_stopWatchTimer),
                  WalkLength(totalWalkLength),
                  CircleAvatar(
                    backgroundColor: btnColor,
                    radius: 20,
                    child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: pressWalkBtn
                            ? Icon(Icons.stop)
                            : Icon(Icons.play_arrow),
                        color: Color(0xFFFFFDF4),
                        iconSize: 30,
                        onPressed: () {
                          setState(() {
                            if (pressWalkBtn == false) {
                              // 버튼 변경
                              pressWalkBtn = true;
                              debugPrint(pressWalkBtn.toString());

                              // 카카오 맵 이동 기록 시작
                              Future<Position> future = _determinePosition();
                              future
                                  .then((pos) => startWalk(pos, _mapController))
                                  .catchError((error) => debugPrint(error));

                              // 타이머 정지
                              startTime = DateTime.now();
                              _stopWatchTimer =
                                  StopWatchTimer(mode: StopWatchMode.countUp);
                              _stopWatchTimer.onStartTimer();
                              // _stopWatchTimer.secondTime
                              //     .listen((value) => print('secondTime $value'));
                            } else if (pressWalkBtn == true) {
                              // 버튼 변경
                              pressWalkBtn = false;
                              debugPrint(pressWalkBtn.toString());

                              // 카카오 맵 이동 기록 중단
                              stopWalk(_mapController);

                              // 타이머 정지
                              // _stopWatchTimer.dispose();
                              _stopWatchTimer.onStopTimer();
                              endTime = DateTime.now();

                              // 백엔드 서버로 전송
                              List<int> pets = [1, 2, 3];
                              putWalk info = new putWalk(
                                  startTime: startTime.toIso8601String(),
                                  endTime: endTime.toIso8601String(),
                                  distance: totalWalkLength,
                                  pet_ids: pets);
                              // 반려동물 1, 2, 3은 예시용(수정필요)
                              ApiWalk apiWalk = ApiWalk();
                              apiWalk.enterWalk(info);

                              // 스크린샷 저장
                              // final directory =
                              //     (await getApplicationDocumentsDirectory())
                              //         .path; //from path_provide package
                              // String fileName = DateTime.now()
                              //     .microsecondsSinceEpoch;
                              // debugPrint(fileName);
                              // path = '$directory';
                              // screenshotController.captureAndSave(fileName);

                            }
                          });
                        }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // bottomNavigationBar: bottomNavBar(
      //     back_com: pColor,
      //     back_home: pColor,
      //     back_loc: sColor,
      //     icon_color_com: btnColor,
      //     icon_color_home: btnColor,
      //     icon_color_loc: Color(0xFFFFFDF4)),
    ); // 수정중
  }
}

/// 기능 functions
/// 디바이스의 현재 위치 결정
/// 위치 서비스가 활성화 되어있지 않거나 권한이 없는 경우 `Future` 에러
Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await _geolocatorPlatform.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('위치 서비스 비활성화');
  }

  // 백그라운드 GPS 권한 요청
  permission = await _geolocatorPlatform.checkPermission();
  // permission = await Permission.locationAlways.status;
  if (permission == LocationPermission.denied) {
    Permission.locationAlways.request();
    permission = await _geolocatorPlatform.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('위치 정보 권한이 없음');
    }
  }

  if (permission == PermissionStatus.granted) {
    return await _geolocatorPlatform.getCurrentPosition();
  } else if (permission == PermissionStatus.permanentlyDenied) {
    return Future.error('백그라운드 위치정보 권한이 영구적으로 거부되어 권한을 요청할 수 없습니다.');
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error('위치정보 권한이 영구적으로 거부되어 권한을 요청할 수 없습니다.');
  }

  return await _geolocatorPlatform.getCurrentPosition();
}

void startWalk(Position position, _mapController) {
  // 연속적인 위치 정보 기록에 사용될 설정
  LocationSettings locationSettings;
  if (defaultTargetPlatform == TargetPlatform.android) {
    locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
        intervalDuration: const Duration(milliseconds: 500),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "백그라운드에서 위치정보를 받아오고 있습니다.",
          notificationTitle: "견생실록이 백그라운드에서 실행중입니다.",
        ));
  } else if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    locationSettings = AppleSettings(
      accuracy: LocationAccuracy.high,
      activityType: ActivityType.fitness,
      distanceFilter: 10,
      pauseLocationUpdatesAutomatically: true,
      showBackgroundLocationIndicator: false,
    );
  } else {
    locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  var lat = position.latitude, // 위도
      lon = position.longitude; // 경도
  totalWalkLength = 0;
  positionList = [];

  _mapController.runJavascript('''
                  map.setDraggable(false);
                  map.setZoomable(false);
  ''');

  _positionStreamSubscription = _geolocatorPlatform
      .getPositionStream(locationSettings: locationSettings)
      .listen((Position? position) {
    if (!positionList.contains(position)) {
      if (positionList.length > 0) {
        drawLine(_mapController, position, positionList.last);
      }
      positionList.add(position!);
    }
  });
  if (positionList.length == 0) {
    _mapController.runJavascript('''
                  if ('$position') {
                  // GeoLocator을 이용해서 얻어온 접속 위치로 이동합니다
                    var lat = parseFloat('$lat'), // 위도
                        lon = parseFloat('$lon'); // 경도
                    var locPosition = new kakao.maps.LatLng(lat, lon);
                    map.setCenter(locPosition);
                      
                  } else { // 위치정보를 사용할 수 없을때 이동할 위치를 설정합니다
                  
                    var locPosition = new kakao.maps.LatLng(37.5013068, 127.0396597); // 멀티캠퍼스 위치
                    map.setCenter(locPosition);
                  }
                  var boundList = [];
            ''');
  }
}

void drawLine(_mapController, position, beforePos) {
  var lat = 0.0, lon = 0.0;
  var beforeLat = 0.0, beforeLon = 0.0;

  lat = position.latitude;
  lon = position.longitude;
  beforeLat = beforePos.latitude;
  beforeLon = beforePos.longitude;
  // 한 번에 너무 먼 거리 이동(오류/차량 등등) 제외
  // if ((lat * 1000).round() == (beforeLat * 1000).round() ||
  //     (lon * 1000).round() == (beforeLon * 1000).round()) {
  // 거리 계산
  double distanceInMeters = _geolocatorPlatform
      .distanceBetween(position.latitude, position.longitude,
          beforePos.latitude, beforePos.longitude)
      .abs();
  // 거리 합산
  totalWalkLength += distanceInMeters.toInt();
  // }

  debugPrint('그리는 중');
  _mapController.runJavascript('''
                    var lat = parseFloat('$lat'), // 위도
                        lon = parseFloat('$lon'); // 경도
                    var beforeLat = parseFloat('$beforeLat'), // 위도
                        beforeLon = parseFloat('$beforeLon'); // 경도
                    var locPosition = new kakao.maps.LatLng(lat, lon);
                    var beforeLocPosition = new kakao.maps.LatLng(beforeLat, beforeLon);
                    var linePath = [];
                    
                    boundList.push(locPosition); // 바운드 영역 계산용 위치 추가
                    
                    map.setCenter(locPosition);
                    linePath.push(beforeLocPosition);
                    linePath.push(locPosition);
                    
                    // 지도에 표시할 선을 생성합니다
                    var polyline = new kakao.maps.Polyline({
                        path: linePath, // 선을 구성하는 좌표배열 입니다
                        strokeWeight: 5, // 선의 두께 입니다
                        strokeColor: '#FFAE00', // 선의 색깔입니다
                        strokeOpacity: 0.7, // 선의 불투명도 입니다 1에서 0 사이의 값이며 0에 가까울수록 투명합니다
                        strokeStyle: 'solid' // 선의 스타일입니다
                    });
                    
                    // 지도에 선을 표시합니다 
                    polyline.setMap(map);
            ''');
}

void stopWalk(_mapController) {
  debugPrint(totalWalkLength.toString());
  _positionStreamSubscription?.cancel(); // 위치 기록 종료
  _mapController.runJavascript('''
                     map.setDraggable(true);
                     map.setZoomable(true);
                     var bounds = new kakao.maps.LatLngBounds();    
                      for (i = 0; i < boundList.length; i++) {                          
                          // LatLngBounds 객체에 좌표를 추가합니다
                          bounds.extend(boundList[i]);
                      }
                     map.setBounds(bounds);
                     // bounds[, paddingTop, paddingRight, paddingBottom, paddingLeft]
                     // map.setCenter(new kakao.maps.LatLng(latitude,longitude));
  ''');
  positionList = [];
  debugPrint('산책 끝');
}
