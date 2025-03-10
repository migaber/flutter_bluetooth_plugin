import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_plugin/flutter_bluetooth_plugin.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(title: 'Bluetooth Scanner'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  BluetoothManager bluetoothManager = BluetoothManager.instance;

  bool _connected = false;
  BluetoothDevice? _device;
  String tips = 'no device connect';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => initBluetooth());
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initBluetooth() async {
    // Request necessary permissions before starting Bluetooth operations
    await _requestPermissions();

    // Only proceed with Bluetooth operations if permissions are granted
    try {
      bluetoothManager.startScan(timeout: Duration(seconds: 4));

      bool isConnected = await bluetoothManager.isConnected;

      bluetoothManager.state.listen((state) {
        log('cur device status: $state');

        switch (state) {
          case BluetoothManager.CONNECTED:
            setState(() {
              _connected = true;
              tips = 'connect success';
            });
            break;
          case BluetoothManager.DISCONNECTED:
            setState(() {
              _connected = false;
              _device = null;
              tips = 'disconnect success';
            });
            break;
          default:
            break;
        }
      });

      if (!mounted) return;

      if (isConnected) {
        setState(() {
          _connected = true;
        });
      }
    } catch (e) {
      log('Error initializing Bluetooth: $e');
      setState(() {
        tips = 'Bluetooth error: ${e.toString()}';
      });
    }
  }

  // Request all necessary Bluetooth permissions
  Future<void> _requestPermissions() async {
    // Request permissions based on Android version
    if (await Permission.bluetoothScan.status.isDenied ||
        await Permission.bluetoothConnect.status.isDenied ||
        await Permission.location.status.isDenied) {
      log('Requesting Bluetooth permissions...');

      // Request permissions
      Map<Permission, PermissionStatus> statuses =
          await [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
            Permission.location,
          ].request();

      // Log permission statuses
      statuses.forEach((permission, status) {
        log('$permission: $status');
      });

      // Check if permissions are still denied
      if (statuses[Permission.bluetoothScan]!.isDenied ||
          statuses[Permission.bluetoothConnect]!.isDenied ||
          statuses[Permission.location]!.isDenied) {
        setState(() {
          tips =
              'Bluetooth permissions denied. Please enable them in settings.';
        });
        log('Bluetooth permissions denied');
      }
    }
  }

  void _onConnect() async {
    if (_device != null && _device!.address != null) {
      await bluetoothManager.connect(_device!);
    } else {
      setState(() {
        tips = 'please select device';
      });
      log('please select device');
    }
  }

  void _onDisconnect() async {
    await bluetoothManager.disconnect();
  }

  void _sendData() async {
    List<int> bytes = latin1.encode('Hello world!\n\n\n').toList();

    // Set codetable west. Add import 'dart:typed_data';
    // List<int> bytes = Uint8List.fromList(List.from('\x1Bt'.codeUnits)..add(6));
    // Text with special characters
    // bytes += latin1.encode('blåbærgrød\n\n\n');

    await bluetoothManager.writeData(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh:
            () => bluetoothManager.startScan(timeout: Duration(seconds: 4)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    child: Text(tips),
                  ),
                ],
              ),
              Divider(),
              StreamBuilder<List<BluetoothDevice>>(
                stream: bluetoothManager.scanResults,
                initialData: [],
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<BluetoothDevice>> snapshot,
                ) {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final device = snapshot.data![index];

                        return Card(
                          elevation: 2,
                          child: ListTile(
                            title: Text(device.name ?? 'Unknown Device $index'),
                            subtitle: Text(device.address ?? 'Unknown Address'),
                            trailing:
                                _device?.address != null &&
                                        device.address == _device?.address
                                    ? Icon(
                                      Icons.check,
                                      color: Colors.lightGreen,
                                    )
                                    : null,
                            onTap: () {
                              log(
                                'Selected device: ${device.name} (${device.address})',
                              );
                              setState(() {
                                _device = device;
                              });
                            },
                          ),
                        );
                      },
                    );
                  } else {
                    return Card(
                      elevation: 2,
                      margin: EdgeInsets.all(16),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.bluetooth_disabled,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No Bluetooth devices found",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Pull down to refresh or press the scan button",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
              Divider(),
              Container(
                padding: EdgeInsets.fromLTRB(20, 5, 20, 10),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        OutlinedButton(
                          onPressed: _connected ? null : _onConnect,
                          child: Text('connect'),
                        ),
                        SizedBox(width: 10.0),
                        OutlinedButton(
                          onPressed: _connected ? _onDisconnect : null,
                          child: Text('disconnect'),
                        ),
                      ],
                    ),
                    OutlinedButton(
                      onPressed: _connected ? _sendData : null,
                      child: Text('Send test data'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: bluetoothManager.isScanning,
        initialData: false,
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return FloatingActionButton(
              onPressed: () => bluetoothManager.stopScan(),
              backgroundColor: Colors.red,
              child: Icon(Icons.stop),
            );
          } else {
            return FloatingActionButton(
              onPressed: () async {
                try {
                  await bluetoothManager.startScan(
                    timeout: Duration(seconds: 4),
                  );
                } catch (e) {
                  log('Error starting scan: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              backgroundColor: Colors.blue,
              child: Icon(Icons.search),
            );
          }
        },
      ),
    );
  }
}
