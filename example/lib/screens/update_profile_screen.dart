import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter_example/widgets/error_dialog.dart';
import 'package:adapty_flutter_example/widgets/simple_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UpdateProfileScreen extends StatefulWidget {
  @override
  _UpdateProfileScreenState createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneNumberController = TextEditingController();
  DateTime? birthdayDate;
  AdaptyProfileGender? gender;

  Future<bool> _updateProfile() async {
    final firstName = firstNameController.text;
    final lastName = lastNameController.text;
    final phoneNumber = phoneNumberController.text;
    final birthdayDateLocal = birthdayDate;
    final genderLocal = gender;
    final profileBuilder = AdaptyProfileParametersBuilder();
    if (firstName.isNotEmpty) profileBuilder.setFirstName(firstName);
    if (lastName.isNotEmpty) profileBuilder.setLastName(lastName);
    if (phoneNumber.isNotEmpty) profileBuilder.setPhoneNumber(phoneNumber);
    if (birthdayDateLocal != null) profileBuilder.setBirthday(birthdayDateLocal);
    if (genderLocal != null) profileBuilder.setGender(genderLocal);

    bool result = false;
    try {
      result = await Adapty.updateProfile(profileBuilder.build());
      print('#Example# updateProfile done!');
    } on AdaptyError catch (adaptyError) {
      AdaptyErrorDialog.showAdaptyErrorDialog(context, adaptyError);
    } catch (e) {
      print('#Example# updateProfile error $e');
    }
    return result;
  }

  void _showSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(buildSimpleSnackbar('Profile updated.'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Profile'),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_outlined,
            size: 24,
          ),
          onPressed: Navigator.of(context).pop,
        ),
      ),
      body: Builder(
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('First Name:', style: TextStyle(fontSize: 17)),
                  TextField(
                    decoration: InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                    controller: firstNameController,
                  ),
                  SizedBox(
                    height: 16,
                  ),
                  Text('Last Name:', style: TextStyle(fontSize: 17)),
                  TextField(
                    decoration: InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                    controller: lastNameController,
                  ),
                  SizedBox(
                    height: 16,
                  ),
                  Text('Phone Number:', style: TextStyle(fontSize: 17)),
                  TextField(
                    decoration: InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                    controller: phoneNumberController,
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(
                    height: 16,
                  ),
                  Text('Birthday:', style: TextStyle(fontSize: 17)),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(birthdayDate != null ? DateFormat.yMMMMd().format(birthdayDate!) : '', style: TextStyle(fontSize: 17)),
                        IconButton(
                            icon: Icon(Icons.calendar_today_sharp),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: ctx,
                                initialDate: birthdayDate ?? DateTime(2000),
                                firstDate: DateTime(1990),
                                lastDate: DateTime.now(),
                              );
                              setState(() {
                                if (date != null) {
                                  birthdayDate = date;
                                }
                              });
                            })
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 16,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gender:', style: TextStyle(fontSize: 17)),
                      DropdownButton<AdaptyProfileGender>(
                        value: gender,
                        icon: Icon(Icons.arrow_drop_down_outlined),
                        iconSize: 30,
                        // style: TextStyle(color: Colors.deepPurple),
                        underline: Container(
                          height: 2,
                          // color: Colors.grey,
                        ),
                        onChanged: (newValue) {
                          setState(() {
                            gender = newValue;
                          });
                        },
                        items: AdaptyProfileGender.values.map((value) {
                          return DropdownMenuItem<AdaptyProfileGender>(
                            value: value,
                            child: Text(value.toString()),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final res = await _updateProfile();
                          if (res) {
                            _showSnackBar();
                          }
                        },
                        child: Text('Update Profile'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
