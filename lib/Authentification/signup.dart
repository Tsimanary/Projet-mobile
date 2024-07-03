import 'package:appharmacie/Authentification/login.dart';
import 'package:appharmacie/Models/users.dart';
import 'package:appharmacie/SQLite/sqlite.dart';
import 'package:flutter/material.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {

  final username = TextEditingController();
  final password = TextEditingController();
  final confirmpassword = TextEditingController();

  final formkey = GlobalKey<FormState>();

  bool isVisible = false;
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Form(
              key: formkey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  const ListTile(
                    title: Text("Register New Account",
                    style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // As we assigned our controller to the textformfields
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

                  //Confirm password
                  Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.green.withOpacity(.2),
                    ),
                    child:  TextFormField(
                      controller: confirmpassword,
                      validator: (value) {
                        if (value!.isEmpty){
                          return"password is required";
                        }else if (password.text != confirmpassword.text){
                          return "password don't match";
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
                  //Login button
                  Container(
                    height: 55,
                    width: MediaQuery.of(context).size.width * .9,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.green),
                    child: TextButton(onPressed: () {
                      if(formkey.currentState!.validate()){
                        //Login method will be here
                        final db = DatabaseHelper();
                        db.signup(Users(usrName: username.text, usrPassword: password.text))
                            .whenComplete((){
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (context)=> const LoginPage()));
                        });
                      }
                    },
                        child: const Text("SIGN UP",
                          style: TextStyle(color: Colors.white),)),
                  ),

                  //Sign up button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Vous avez de compte ? "),
                      TextButton(onPressed: () {
                        //Navigate to sign up
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>const LoginPage()));
                      }, child: const Text("LOGIN"))
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
