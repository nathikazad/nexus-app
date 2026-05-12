import 'package:nx_db/riverpod.dart';
import 'package:nx_people/data/person/person_attr_keys.dart';

final personSchemaProvider = kgqlModelTypeForPersonalDomain(
  kPersonModelTypeName,
);
