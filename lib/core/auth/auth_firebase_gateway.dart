import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

abstract class AuthFirebaseGateway {
  AuthFirebaseUser? get currentUser;

  Stream<AuthFirebaseUser?> authStateChanges();

  Future<AuthFirebaseUser?> signInWithCredential(AuthCredential credential);

  Future<void> reauthenticateWithCredential(AuthCredential credential);

  Future<void> signOut();
}

abstract class AuthGoogleGateway {
  Future<GoogleSignInAccount?> signIn();

  Future<void> signOut();
}

class FirebaseAuthGateway implements AuthFirebaseGateway {
  final FirebaseAuth _auth;

  FirebaseAuthGateway({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  @override
  AuthFirebaseUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : FirebaseUserAdapter(user);
  }

  @override
  Stream<AuthFirebaseUser?> authStateChanges() {
    return _auth.authStateChanges().map(
      (user) => user == null ? null : FirebaseUserAdapter(user),
    );
  }

  @override
  Future<AuthFirebaseUser?> signInWithCredential(
    AuthCredential credential,
  ) async {
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    return user == null ? null : FirebaseUserAdapter(user);
  }

  @override
  Future<void> reauthenticateWithCredential(AuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No authenticated user.',
      );
    }
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

class GoogleSignInGateway implements AuthGoogleGateway {
  final GoogleSignIn _googleSignIn;

  GoogleSignInGateway({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn();

  @override
  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  @override
  Future<void> signOut() => _googleSignIn.signOut();
}

abstract class AuthFirebaseUser {
  String get uid;
  String? get displayName;
  String? get photoURL;
  String? get phoneNumber;
}

class FirebaseUserAdapter implements AuthFirebaseUser {
  final User _user;

  FirebaseUserAdapter(this._user);

  @override
  String get uid => _user.uid;

  @override
  String? get displayName => _user.displayName;

  @override
  String? get photoURL => _user.photoURL;

  @override
  String? get phoneNumber => _user.phoneNumber;
}
