import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';

void main() {

  final channel = ClientChannel(
    'localhost',
    port: 50051,
    options: ChannelOptions(
      credentials: ChannelCredentials.insecure(),
      codecRegistry:
      CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
    ),
  );
  print("Just use some grpc API: $channel");

  runApp(const ProjectApp());
}

class ProjectApp extends StatelessWidget {
  const ProjectApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sample Project',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ProjectWidget(),
    );
  }
}

class ProjectWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Project"),
        ),
        body: Center(
            child: Text(
          'Sample Project',
        )));
  }
}
