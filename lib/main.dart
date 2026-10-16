import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/branding/brand_licenses.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerBrandLicenses();
  runApp(const ProviderScope(child: WmsMobileApp()));
}
