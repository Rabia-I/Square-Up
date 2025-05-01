import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  String name;
  String profilePhoto;
  String email;
  String uid;
  List<String> followers;
  List<String> following;
  Timestamp createdAt;

  User({
    required this.name,
    required this.email,
    required this.uid,
    required this.profilePhoto,
    required this.followers,
    required this.following,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    "name": name,
    "profilePhoto": profilePhoto,
    "email": email,
    "uid": uid,
    "followers": followers,
    "following": following,
    "createdAt": createdAt,
  };

  static User fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return User(
      email: snapshot['email'],
      profilePhoto: snapshot['profilePhoto'],
      uid: snapshot['uid'],
      name: snapshot['name'],
      followers: List<String>.from(snapshot['followers'] ?? []),
      following: List<String>.from(snapshot['following'] ?? []),
      createdAt: snapshot['createdAt'] ?? Timestamp.now(),
    );
  }
}
