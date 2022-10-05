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
  bool _heaterEnabled = true;
  bool _vibrationEnabled = true;
  bool _override = false;
  bool _devMode = false;
  int _lastBPM = 80;
  int _overrideBPM = 80;
  final FlutterBlue _flutterBlue = FlutterBlue.instance;
  BluetoothDevice? _pillow;
  BluetoothDevice? _watch;
  BluetoothCharacteristic? _heartbeatCharacteristic;
  BluetoothCharacteristic? _enableCharacteristic;
  BluetoothCharacteristic? _watchCharacteristic;

  void _enableUpdate() async {
    int hE = _heaterEnabled ? 0 : 0;
    int vE = _vibrationEnabled ? 1 : 0;
    print("he");
    if (_pillowConnected) {
      print("hello");
      await _enableCharacteristic?.write([hE * 2 + vE]);
    }
  }

  void _updateOverrideBPM(double value) async {
    setState(() {
      _overrideBPM = value.toInt();
    });
    if (_pillowConnected && _override) {
      await _heartbeatCharacteristic?.write([_overrideBPM], withoutResponse: false);
    }
  }

  void _toggleDev() {
    setState(() {
      _devMode = !_devMode;
    });
  }

  void _toggleVibration(bool value) {
    _vibrationEnabled = value;
    _enableUpdate();
    setState(() {
      _vibrationEnabled = _vibrationEnabled;
    });
  }

  void _toggleHeater(bool value) {
    _heaterEnabled = value;
    _enableUpdate();
    setState(() {
      _heaterEnabled = _heaterEnabled;
    });
  }

  void _toggleOverride(bool value) {
    setState(() {
      _override = value;
    });
    if (value) {
      _updateOverrideBPM(_overrideBPM.toDouble());
    } else {
      _updatePillow();
    }
  }

  void _connectPillow() async {
    if (!_pillowConnected) {
      await Future.wait([
        _flutterBlue.scan().listen((r) {
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
          for (BluetoothCharacteristic c in service.characteristics) {
            print(c.uuid.toString());
            if (c.uuid.toString() == "c2abad98-a402-42a8-8981-edf54dd7d6ef") {
              _enableCharacteristic = c;
            } else if (c.uuid.toString() ==
                "69e01dc5-b098-417a-9e2e-be69bc86c2ae") {
              _heartbeatCharacteristic = c;
            }
          }
        }
      });
      await Future.delayed(const Duration(seconds: 1));
      _enableUpdate();
    } else {
      await _pillow?.disconnect();
      _pillowConnected = false;
    }

    setState(() {
      _pillowConnected = _pillowConnected;
    });
  }

  void _updatePillow() async {
    await _heartbeatCharacteristic?.write([_lastBPM], withoutResponse: false);
  }

  void _connectWatch() async {
    if (!_watchConnected) {
      await Future.wait([
        _flutterBlue.scan(timeout: const Duration(seconds: 10)).listen((r) {
          if (r.device.id.id == "FA:3B:3C:5E:B9:2C") {
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
        if (value[1] == 0) {
          return;
        }
        setState(() {
          _lastBPM = value[1];
        });
        if (_watchConnected && _pillowConnected && !_override) {
          _updatePillow();
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
          ),
          Visibility(
              visible: _devMode,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Enable Vibration"),
                      Switch(
                          value: _vibrationEnabled, onChanged: _toggleVibration)
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Enable Heater"),
                      Switch(value: _heaterEnabled, onChanged: _toggleHeater)
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Manual BPM Override"),
                      Switch(value: _override, onChanged: _toggleOverride)
                    ],
                  ),
                  Slider(
                      value: _overrideBPM.toDouble(),
                      max: 180,
                      divisions: 18,
                      label: _overrideBPM.round().toString(),
                      onChanged: _updateOverrideBPM)
                ],
              )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleDev,
        tooltip: 'Dev Mode',
        child: const Icon(Icons.settings),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
