import 'package:appharmacie/Authentification/signup.dart';
import 'package:appharmacie/Models/users.dart';
import 'package:appharmacie/SQLite/sqlite.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:get/get.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final username = TextEditingController();
  final password = TextEditingController();

  bool isVisible = false;

  bool isLoginTrue = false;

  final db = DatabaseHelper();

  //Now we should call this function in login button

  void login() async {
    var response = await db.login(Users(usrName: username.text, usrPassword: password.text));
    if (response == true) {
      // Si la connexion est correcte, naviguer vers HomePage
      if (!mounted) return;
      Get.off(() => const HomePage()); // Utilisation de Get.off pour remplacer la page actuelle
    } else {
      setState(() {
        isLoginTrue = true;
      });
    }
  }

  //We have to create global key for our form
  final formkey = GlobalKey<FormState>();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            //We put all our textfield to a form to be controlled and not allow as empty
            child: Form(
              key: formkey,
              child: Column(
                children: [
                  //Username field
                  Image.asset(
                    "lib/assets/images/Drugst.png",
                    width: 370,
                  ),
                  const SizedBox(height: 15),
                  Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.green.withOpacity(.2),
                    ),
                    child:  TextFormField(
                      controller: username,
                      validator: (value) {
                        if (value!.isEmpty){
                          return"username is required";
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        icon: Icon(Icons.person),
                        border: InputBorder.none,
                        hintText: "Username", // corrected 'label' to 'labelText'
                      ),
                    ),
                  ),
                  //Password field
                  Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.green.withOpacity(.2),
                    ),
                    child:  TextFormField(
                      controller: password,
                      validator: (value) {
                        if (value!.isEmpty){
                          return"password is required";
                        }
                        return null;
                      },
                      obscureText: !isVisible,
                      decoration: InputDecoration(
                        icon: const Icon(Icons.lock),
                        border: InputBorder.none,
                        hintText: "Password",
                        suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                isVisible = !isVisible;
                              });
                            }, icon: Icon(isVisible
                            ? Icons.visibility
                            : Icons.visibility_off
                        ))
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  //SignUp button
                  Container(
                    height: 55,
                    width: MediaQuery.of(context).size.width * .9,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.green),
                    child: TextButton(onPressed: () {
                      if(formkey.currentState!.validate()){
                        //Login method will be here
                        login();
                      }
                    },
                        child: const Text("LOGIN",
                          style: TextStyle(color: Colors.white),)),
                  ),
                  
                  //Sign up button
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("vous n'avez pas de compte ? Cliquez sur "),
                      TextButton(onPressed: () {
                        //Navigate to sign up
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>const SignUp()));
                      }, child: const Text("SIGN UP"))
                    ],
                  ),
                  isLoginTrue? const Text("Username or password is incorrect",
                    style: TextStyle(color: Colors.red),
                  )
                      :const SizedBox(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}