import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:square_up/models/user.dart' as model;
import 'package:square_up/views/screens/auth/login_screen.dart';
import 'package:square_up/views/screens/home_screen.dart';

class AuthController extends GetxController {
  static AuthController instance = Get.find();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  late Rx<auth.User?> _user;
  final Rx<File?> _pickedImage = Rx<File?>(null);

  auth.User? get user => _user.value;
  File? get profilePhoto => _pickedImage.value;

  @override
  void onReady() {
    super.onReady();
    _user = Rx<auth.User?>(_auth.currentUser);
    _user.bindStream(_auth.authStateChanges());
    ever(_user, _setInitialScreen);
  }

  void _setInitialScreen(auth.User? user) async {
    if (user == null) {
      Get.offAll(() => LoginScreen());
    } else {
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          Get.offAll(() => const HomeScreen());
        } else {
          await _auth.signOut();
          Get.snackbar('No Account', 'User profile not found. Please sign up.');
          Get.offAll(() => LoginScreen());
        }
      } catch (e) {
        print('Error checking Firestore user doc: $e');
        Get.snackbar('Error', 'Something went wrong.');
      }
    }
  }

  Future<void> pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        _pickedImage.value = File(picked.path);
        Get.snackbar('Profile Picture', 'Image selected');
      } else {
        Get.snackbar('Error', 'No image selected');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e');
    }
  }

  Future<String> _uploadToStorage(File image) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw 'User not authenticated';
      final ref = _storage.ref().child('profilePics').child('$uid.jpg');

      final uploadTask = await ref.putFile(image);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Image upload failed: $e');
      rethrow;
    }
  }

  Future<void> registerUser(
      String username,
      String email,
      String password,
      File? image,
      ) async {
    if (username.isEmpty || email.isEmpty || password.isEmpty || image == null) {
      Get.snackbar('Error', 'Please fill all fields and select a profile picture');
      return;
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final downloadUrl = await _uploadToStorage(image);

      final user = model.User(
        name: username,
        email: email,
        uid: cred.user!.uid,
        profilePhoto: downloadUrl,
        followers: [],
        following: [],
        createdAt: Timestamp.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(user.toJson());

      Get.offAll(() => const HomeScreen());
    } catch (e) {
      Get.snackbar('Registration Error', e.toString());
    }
  }

  Future<void> loginUser(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      Get.snackbar('Error', 'Email & password required');
      return;
    }
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      Get.snackbar('Login Error', e.toString());
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    Get.offAll(() => LoginScreen());
  }

  Future<void> getUserData(String uid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('User is null, aborting getUserData');
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        print('No such user found in Firestore');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final currentDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final currentData = currentDoc.data() as Map<String, dynamic>? ?? {};

      final followingList = (currentData['following'] ?? []) as List;
      userData['isFollowing'] = followingList.contains(uid);

      update();
    } catch (e) {
      print('Error in getUserData: $e');
    }
  }
}