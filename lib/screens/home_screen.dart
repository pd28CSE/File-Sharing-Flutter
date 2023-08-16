import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
// import 'package:http/http.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:path_provider/path_provider.dart';

import 'package:file_picker/file_picker.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final String baseUrl = 'https://filesharingbd.pythonanywhere.com';
  final Dio dio = Dio();
  late final TextEditingController codeController;
  String selectedFileName = '';
  File? selectedFile;
  String qrImage = '';
  String id = '';
  bool isFileSendingInProgress = false;
  bool isFileUrlFetchingInProgress = false;
  bool isFileDownloadingInProgress = false;
  double downloadComplete = 0.0;

  @override
  void initState() {
    codeController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () async {
                    await selectFile();
                  },
                  icon: const Icon(Icons.file_present_rounded),
                  label: Text('Select File $selectedFileName'),
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: (isFileDownloadingInProgress ||
                              isFileUrlFetchingInProgress ||
                              isFileSendingInProgress) ==
                          true
                      ? null
                      : () {
                          sendFile();
                        },
                  icon: const Icon(Icons.file_upload_sharp),
                  label: Visibility(
                    visible: isFileSendingInProgress == false,
                    replacement: const CircularProgressIndicator(),
                    child: const Text('Send File'),
                  ),
                ),
                const SizedBox(height: 10),
                if (qrImage.isNotEmpty) ...<Widget>[
                  SelectableText(
                    id,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 25,
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.transparent,
                    radius: 100,
                    child: SvgPicture.memory(
                      base64Decode(qrImage),
                      fit: BoxFit.contain,
                      height: 180,
                    ),
                  ),
                ],
                if (isFileDownloadingInProgress == true)
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Slider(
                          label: '${downloadComplete.toStringAsFixed(0)}%',
                          divisions: 100,
                          min: 0.0,
                          max: 100.0,
                          value: downloadComplete,
                          onChanged: (value) {
                            // log(value.toString());
                            // setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 5),
                      Chip(
                        label: Text('${downloadComplete.toStringAsFixed(0)}%'),
                      ),
                    ],
                  ),
                if (isFileSendingInProgress == false)
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: 'Enter PIN',
                      suffix: IconButton(
                        onPressed: (isFileDownloadingInProgress ||
                                    isFileUrlFetchingInProgress) ==
                                true
                            ? null
                            : () async {
                                if (codeController.text.trim().isNotEmpty) {
                                  await downloadFile(
                                      codeController.text.trim());
                                }
                              },
                        icon: (isFileDownloadingInProgress ||
                                    isFileUrlFetchingInProgress) ==
                                true
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.download),
                      ),
                    ),
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> selectFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null) {
      selectedFileName = result.files[0].name;
      setState(() {});
      // log(result.paths[0].toString());
      selectedFile = File(result.files[0].path!);
      return true;
    }
    return false;
  }

  Future<void> sendFile() async {
    if (selectedFile == null) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)!.clearSnackBars();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No File Selected!')));
      }
      return;
    } else {
      isFileSendingInProgress = true;
      if (mounted) {
        setState(() {});
      }
      try {
        FormData formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(
            selectedFile!.path,
            filename: selectedFile.toString().split('/').last,
          ),
        });
        Response response = await dio.post(
          '$baseUrl/file-share-bd-api/',
          data: formData,
        );
        if (response.statusCode == 202) {
          Map<String, dynamic> responseData = response.data;
          id = '${responseData['id']}';
          qrImage = responseData['qrImage'];
          selectedFile = null;
          selectedFileName = '';
          setState(() {});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              backgroundColor: Colors.green,
              content: Text('File upload complete.'),
            ));
          }
        }
      } catch (e) {
        (e.toString());
      }
      isFileSendingInProgress = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<Map<String, dynamic>?> getFileUrl(String pinCode) async {
    isFileUrlFetchingInProgress = true;
    if (mounted) {
      setState(() {});
    }
    try {
      Response response = await dio.post(
        '$baseUrl/file-share-bd-api/serve-file/',
        options: Options(headers: {
          HttpHeaders.contentTypeHeader: "application/json",
        }),
        data: jsonEncode({"id": pinCode}),
      );
      isFileUrlFetchingInProgress = false;
      if (mounted) {
        setState(() {});
      }
      log(response.data.toString());
      if (response.statusCode == 200) {
        return response.data;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color.fromARGB(255, 233, 27, 12),
              content: Text('File not found or PIN has expired or wrong.'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color.fromARGB(255, 228, 23, 9),
              content: Text('Something is wrong!'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color.fromARGB(255, 236, 22, 7),
            content: Text('Server error!'),
          ),
        );
      }
    }

    isFileUrlFetchingInProgress = false;
    if (mounted) {
      setState(() {});
    }
    return null;
  }

  Future<void> downloadFile(String pinCode) async {
    final File appDownloadPath = File('/storage/emulated/0/Download/');
    final Map<String, dynamic>? responseData = await getFileUrl(pinCode);
    if (responseData == null) {
      return;
    }
    isFileDownloadingInProgress = true;
    if (mounted) {
      setState(() {});
    }
    try {
      await dio.download(
        '$baseUrl/${responseData['file']}',
        "${appDownloadPath.path}/${responseData['file'].split('/').last}",
        onReceiveProgress: (rec, total) {
          // log('--------------------');
          // log('Total: $total');
          downloadComplete = (rec / total) * 100.0;
          // log('Complete: $downloadComplete');
          // log('--------------------');
          setState(() {});
        },
      );
    } catch (e) {
      log(e.toString());
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.red,
          content: Text('File Download Failed!'),
        ));
      }
      isFileDownloadingInProgress = false;
      if (mounted) {
        setState(() {});
      }
      return;
    }
    clearAll();
    isFileDownloadingInProgress = false;
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Colors.green,
        content: Text('File download Complete.'),
      ));
    }
  }

  void clearAll() {
    downloadComplete = 0.0;
    codeController.clear();
    selectedFileName = '';
    qrImage = '';
    selectedFile = null;
  }

  // Future<void?> usingHttp() {
  //   if (selectedFile == null) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context)
  //           .showSnackBar(const SnackBar(content: Text('No File Selected!')));
  //     }
  //   } else {
  //       try {
  //         // String base64file = base64Encode(selectedFile.readAsBytesSync());

  //       MultipartRequest request = MultipartRequest(
  //         'POST',
  //         Uri.parse('http://10.0.2.2:8000/file-share-bd-api/'),
  //       );
  //       request.files
  //           .add(await MultipartFile.fromPath('file', selectedFile!.path));
  //       StreamedResponse streamedResponse = await request.send();
  //       final Response response = await Response.fromStream(streamedResponse);
  //       if (response.statusCode == 202) {
  //         print('------------');

  //         Map<String, dynamic> responseBody = jsonDecode(response.body);
  //         // log(responseBody['id']);
  //         // log(responseBody['qrImage']);
  //         id = '${responseBody['id']}';
  //         qrImage = responseBody['qrImage'];
  //         setState(() {});
  //         if (mounted) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //               const SnackBar(content: Text('File Upload Successfull.')));
  //         }
  //       }
  //       }
  //       catch (e){
  //         print(e);
  //       }
  //   }
  // }
}
