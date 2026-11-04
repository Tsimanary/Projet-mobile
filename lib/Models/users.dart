class Users {
  final int? usrId;
  final String usrName;

  /// Mot de passe en clair **uniquement** en entrée (login / signup).
  /// En base, la colonne contient le hachage.
  final String usrPassword;

  /// Sel de hachage (null pour les comptes créés avant la migration).
  final String? usrSalt;

  const Users({
    this.usrId,
    required this.usrName,
    required this.usrPassword,
    this.usrSalt,
  });

  factory Users.fromMap(Map<String, dynamic> json) => Users(
        usrId: (json['usrId'] as num?)?.toInt(),
        usrName: (json['usrName'] ?? '').toString(),
        usrPassword: (json['usrPassword'] ?? '').toString(),
        usrSalt: json['usrSalt'] as String?,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (usrId != null) 'usrId': usrId,
        'usrName': usrName,
        'usrPassword': usrPassword,
        if (usrSalt != null) 'usrSalt': usrSalt,
      };
}
