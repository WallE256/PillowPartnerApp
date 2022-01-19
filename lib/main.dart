import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PillowPartner App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'PillowPartner App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _watchConnected = false;
  bool _pillowConnected = false;
  int _lastBPM = 80;
  final FlutterBlue _flutterBlue = FlutterBlue.instance;
  BluetoothDevice? _pillow;
  BluetoothDevice? _watch = null;
  BluetoothCharacteristic? _pillowCharacteristic;
  BluetoothCharacteristic? _watchCharacteristic;

  void _connectPillow() async {
    if (!_pillowConnected) {
      await Future.wait([_flutterBlue.scan().listen((r) {
        if (r.device.id.id == "84:CC:A8:61:2D:8A") {
          print("hello " + r.device.name);
          _pillow = r.device;
          _flutterBlue.stopScan();
        }
      }).asFuture()
      ]);
      await _pillow?.connect();
      _pillowConnected = true;

      List<BluetoothService>? services = await _pillow?.discoverServices();
      services?.forEach((service) {
        print(service.uuid);
        if (service.uuid.toString() == "61535c46-202a-4859-a213-520ef987c606") {
          _pillowCharacteristic = service.characteristics.first;
        }
      });
    } else {
      await _pillow?.disconnect();
      _pillowConnected = false;
    }

    setState(() {
      _pillowConnected = _pillowConnected;
    });
  }

  void _updatePillow() async {
    await _pillowCharacteristic?.write([_lastBPM], withoutResponse: false);
  }

  void _connectWatch() async {
    if (!_watchConnected) {
      await Future.wait([_flutterBlue.scan(timeout: const Duration(seconds: 10))
          .listen((r) { if (r.device.id.id == "FA:3B:3C:5E:B9:2C") {
          print("hello " + r.device.name);
          _watch = r.device;
          _flutterBlue.stopScan();
        }
      }).asFuture()
      ]);
      await _watch?.connect();
      _watchConnected = true;

      List<BluetoothService>? services = await _watch?.discoverServices();
      services?.forEach((service) {
        if (service.uuid.toString() == "0000180d-0000-1000-8000-00805f9b34fb") {
          _watchCharacteristic = service.characteristics.first;
          print(service.uuid);
        }
      });
      await _watchCharacteristic?.setNotifyValue(true);
      _watchCharacteristic?.value.listen((value) async {
        print(value[1]);
        if (_watchConnected && _pillowConnected) {
          print(_pillowCharacteristic?.uuid);
          setState(() {
            _lastBPM = value[1];
          });
          _updatePillow();
          print("should be ok");
        }
      });

    } else {
      await _watch?.disconnect();
      _watchConnected = false;
    }

    setState(() {
      _watchConnected = _watchConnected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle buttonStyle =
        ElevatedButton.styleFrom(textStyle: Theme.of(context).textTheme.button);
    final TextStyle? statusStyle = Theme.of(context).textTheme.headline5;
    final TextStyle? connectedStyle = Theme.of(context).textTheme.headline6;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Watch status:',
                    style: statusStyle,
                  ),
                  Text(
                    _watchConnected ? "Connected" : "Not Connected",
                    style: connectedStyle,
                  ),
                  ElevatedButton(
                    onPressed: _connectWatch,
                    child: Text(!_watchConnected ? "Connect" : "Disconnect"),
                    style: buttonStyle,
                  ),
                ],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Pillow status:',
                    style: statusStyle,
                  ),
                  Text(
                    _pillowConnected ? "Connected" : "Not Connected",
                    style: connectedStyle,
                  ),
                  ElevatedButton(
                    onPressed: _connectPillow,
                    child: Text(!_pillowConnected ? "Connect" : "Disconnect"),
                    style: buttonStyle,
                  ),
                ],
              )
            ],
          ),
          Column(
            children: [
              Text(
                'Last BPM:',
                style: statusStyle,
              ),
              Text(
                "$_lastBPM",
                style: connectedStyle,
              ),
            ],
          )
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _incrementCounter,
      //   tooltip: 'Increment',
      //   child: const Icon(Icons.add),
      // ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
