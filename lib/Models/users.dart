import '../core/roles.dart';

class Users {
  final int? usrId;
  final String usrName;

  /// Mot de passe en clair **uniquement** en entrée (login / signup).
  /// En base, la colonne contient le hachage Argon2id.
  final String usrPassword;

  /// Sel de hachage de l'ancien format (null pour les comptes Argon2id).
  final String? usrSalt;

  /// Rôle du compte : gestionnaire ou vendeur.
  final RoleUtilisateur usrRole;

  const Users({
    this.usrId,
    required this.usrName,
    required this.usrPassword,
    this.usrSalt,
    this.usrRole = RoleUtilisateur.vendeur,
  });

  factory Users.fromMap(Map<String, dynamic> json) => Users(
        usrId: (json['usrId'] as num?)?.toInt(),
        usrName: (json['usrName'] ?? '').toString(),
        usrPassword: (json['usrPassword'] ?? '').toString(),
        usrSalt: json['usrSalt'] as String?,
        usrRole: RoleUtilisateur.depuis(json['usrRole']?.toString()),
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (usrId != null) 'usrId': usrId,
        'usrName': usrName,
        'usrPassword': usrPassword,
        if (usrSalt != null) 'usrSalt': usrSalt,
        'usrRole': usrRole.valeurBase,
      };
}
