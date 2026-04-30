import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

final formKey = GlobalKey<FormState>();
final emailController = TextEditingController();
final passwordController = TextEditingController();


void registerUser(BuildContext context, String email, String password) async{
  try{
    await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
    QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: 'Success',
      text: 'Your account has been created successfully',
    );
  } catch(e){
    QuickAlert.show(
      context: context,
      type: QuickAlertType.error,
      title: 'Error',
      text: e.toString(),
    );
  }
}


class _RegisterScreenState extends State<RegisterScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Column(
        children: [
          Form(
            key: formKey,
            child: Column( children: [
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if(value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if(EmailValidator.validate(value) == false) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                validator: (value) {
                  if(value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if(value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),

              ElevatedButton(
                onPressed: () {
                  if(formKey.currentState!.validate()) {
                    registerUser(context, emailController.text, passwordController.text);
                  }
                },
                child: const Text('Create Account'),
              )
            ]),
          ),
        ],
      ),
    );
  }
}
