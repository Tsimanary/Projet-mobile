import 'package:appharmacie/core/securite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le sel est aléatoire', () {
    expect(Securite.genererSel(), isNot(Securite.genererSel()));
    expect(Securite.genererSel().length, greaterThan(10));
  });

  test('le hachage ne contient jamais le mot de passe en clair', () {
    final sel = Securite.genererSel();
    final hash = Securite.hasher('motdepasse', sel);

    expect(hash, isNot('motdepasse'));
    expect(hash.length, 64); // SHA-256 en hexadécimal
  });

  test('deux sels différents produisent deux hachages différents', () {
    final premier = Securite.hasher('motdepasse', Securite.genererSel());
    final second = Securite.hasher('motdepasse', Securite.genererSel());

    expect(premier, isNot(second));
  });

  test('la vérification accepte le bon mot de passe et refuse les autres', () {
    final sel = Securite.genererSel();
    final hash = Securite.hasher('motdepasse', sel);

    expect(
      Securite.verifier(motDePasse: 'motdepasse', sel: sel, hashAttendu: hash),
      isTrue,
    );
    expect(
      Securite.verifier(motDePasse: 'autre', sel: sel, hashAttendu: hash),
      isFalse,
    );
    expect(
      Securite.verifier(motDePasse: 'motdepasse', sel: '', hashAttendu: hash),
      isFalse,
    );
  });
}
