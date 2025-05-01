import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:square_up/constants.dart';
import 'package:square_up/controllers/auth_controller.dart';

class ProfileController extends GetxController {
  final Rx<Map<String, dynamic>> _user = Rx<Map<String, dynamic>>({});
  Map<String, dynamic> get user => _user.value;

  final Rx<String> _uid = ''.obs;

  void updateUserId(String uid) {
    _uid.value = uid;
    getUserData();
  }

  Future<void> getUserData() async {
    final currentUser = authController.user;
    final profileUid = _uid.value;

    if (currentUser == null || profileUid.isEmpty) {
      print('User not logged in or UID not set.');
      return;
    }

    try {
      // Videos and thumbnails
      final videoSnap = await firestore
          .collection('videos')
          .where('uid', isEqualTo: profileUid)
          .get();

      final thumbnails = videoSnap.docs.map((doc) {
        return (doc.data() as dynamic)['thumbnail'] as String;
      }).toList();

      // Total likes
      final totalLikes = videoSnap.docs.fold(0, (sum, doc) {
        final likes = (doc.data() as Map<String, dynamic>)['likes'] ?? [];
        return sum + (likes as List).length;
      });

      // User document
      final userDoc = await firestore.collection('users').doc(profileUid).get();
      if (!userDoc.exists) {
        print('No such user found in Firestore');
        return;
      }
      final userData = userDoc.data() as Map<String, dynamic>;

      // Followers and following count
      final followersSnap = await firestore
          .collection('users')
          .doc(profileUid)
          .collection('followers')
          .get();
      final followingSnap = await firestore
          .collection('users')
          .doc(profileUid)
          .collection('following')
          .get();

      // Is current user following this profile?
      final isFollowingDoc = await firestore
          .collection('users')
          .doc(profileUid)
          .collection('followers')
          .doc(currentUser.uid)
          .get();

      // Build final user data
      _user.value = {
        'name': userData['name'],
        'profilePhoto': userData['profilePhoto'],
        'likes': totalLikes.toString(),
        'followers': followersSnap.docs.length.toString(),
        'following': followingSnap.docs.length.toString(),
        'isFollowing': isFollowingDoc.exists,
        'thumbnails': thumbnails,
      };

      update();
    } catch (e) {
      print('Error in getUserData: $e');
    }
  }

  Future<void> followUser() async {
    final currentUser = authController.user;
    if (currentUser == null) return;

    final profileUid = _uid.value;

    final docRef = firestore
        .collection('users')
        .doc(profileUid)
        .collection('followers')
        .doc(currentUser.uid);

    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({});
      await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(profileUid)
          .set({});
      _user.value['followers'] = (int.parse(_user.value['followers']) + 1).toString();
      _user.value['isFollowing'] = true;
    } else {
      await docRef.delete();
      await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(profileUid)
          .delete();
      _user.value['followers'] = (int.parse(_user.value['followers']) - 1).toString();
      _user.value['isFollowing'] = false;
    }

    update();
  }
}
