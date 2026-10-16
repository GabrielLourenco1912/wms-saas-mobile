// Gerado por scripts/sync_branding.py.
import 'dart:ui';

abstract final class BrandColors {
  static const ink = Color(0xFF14251E);
  static const primary = Color(0xFF176B48);
  static const primaryHover = Color(0xFF105337);
  static const onPrimary = Color(0xFFFFFFFF);
  static const accent = Color(0xFFD1F878);
  static const onAccent = Color(0xFF18251F);
  static const soft = Color(0xFFE7F4EC);
  static const background = Color(0xFFF5F6F0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEEF1EB);
  static const text = Color(0xFF18251F);
  static const muted = Color(0xFF5C6B62);
  static const inverseText = Color(0xFFF5F6F0);
  static const inverseMuted = Color(0xFFB6C4B8);
  static const border = Color(0xFFDCE3DA);
  static const control = Color(0xFF7A8A80);
  static const success = Color(0xFF206B46);
  static const successBackground = Color(0xFFE7F4EC);
  static const warning = Color(0xFF855400);
  static const warningBackground = Color(0xFFFFF2CF);
  static const danger = Color(0xFFB42318);
  static const dangerBackground = Color(0xFFFFF0ED);
  static const info = Color(0xFF245BCA);
  static const infoBackground = Color(0xFFEDF3FF);
  static const neutral = Color(0xFF5C6B62);
  static const neutralBackground = Color(0xFFEEF1EB);
}

abstract final class AppBrand {
  static const name = "WMS SaaS";
  static const descriptor = "Gestão de armazéns";
  static const tagline = "Cada movimento, sob controle.";
  static const sansFont = "Manrope";
  static const monoFont = "DM Mono";
  static const authorName = "Gabriel Lourenço";
  static const authorLabel = "Desenvolvido por";
  static const portfolio = "https://lourencogabriel.dev/";
  static const authorLight =
      "assets/branding/author/01-monograma-gl-light-mono.png";
  static const authorDark =
      "assets/branding/author/01-monograma-gl-dark-mono.png";
  static const controlRadius = 8.0;
  static const cardRadius = 12.0;
  static const featureRadius = 24.0;
}

Path createBrandSymbolPath() => Path()
  ..moveTo(16, 28)
  ..lineTo(34, 28)
  ..lineTo(34, 56)
  ..lineTo(46, 76)
  ..lineTo(64, 48)
  ..lineTo(82, 76)
  ..lineTo(94, 56)
  ..lineTo(94, 28)
  ..lineTo(112, 28)
  ..lineTo(112, 62)
  ..lineTo(88, 100)
  ..lineTo(77, 100)
  ..lineTo(64, 80)
  ..lineTo(51, 100)
  ..lineTo(40, 100)
  ..lineTo(16, 62)
  ..close();
