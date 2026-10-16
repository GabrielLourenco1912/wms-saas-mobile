import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

void registerBrandLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    for (final font in ['Manrope', 'DMMono']) {
      final license = await rootBundle.loadString(
        'assets/branding/fonts/$font-OFL.txt',
      );
      yield LicenseEntryWithLineBreaks([
        font == 'DMMono' ? 'DM Mono' : font,
      ], license);
    }
  });
}
