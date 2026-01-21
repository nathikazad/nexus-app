// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import '../providers/models_provider.dart';
// import '../providers/attribute_definitions_provider.dart';
// import '../db.dart';
// import '../widgets/attribute_field.dart';
// import 'package:graphql_flutter/graphql_flutter.dart';

// const String createModelMutation = '''
// mutation CreateModel(\$input: CreateModelInput!) {
//   createModel(input: \$input) {
//     model {
//       id
//       name
//       description
//       modelTypeId
//       createdAt
//       updatedAt
//     }
//   }
// }
// ''';

// const String updateModelMutation = '''
// mutation UpdateModelById(\$id: Int!, \$patch: ModelPatch!) {
//   updateModelById(input: { id: \$id, modelPatch: \$patch }) {
//     model {
//       id
//       name
//       description
//       modelTypeId
//       createdAt
//       updatedAt
//     }
//   }
// }
// ''';

// class ModelFormScreen extends ConsumerStatefulWidget {
//   final int? modelTypeId;
//   final int? modelId;

//   const ModelFormScreen({
//     super.key,
//     this.modelTypeId,
//     this.modelId,
//   });

//   @override
//   ConsumerState<ModelFormScreen> createState() => _ModelFormScreenState();
// }

// class _ModelFormScreenState extends ConsumerState<ModelFormScreen> {
//   final _formKey = GlobalKey<FormState>();
//   late TextEditingController _nameController;
//   late TextEditingController _descriptionController;
//   final Map<String, dynamic> _attributeValues = {};

//   @override
//   void initState() {
//     super.initState();
//     _nameController = TextEditingController();
//     _descriptionController = TextEditingController();

//     if (widget.modelId != null) {
//       // Load existing model data
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         ref.read(modelProvider(widget.modelId!)).whenData((data) {
//           if (data != null && mounted) {
//             _nameController.text = data['name']?.toString() ?? '';
//             _descriptionController.text = data['description']?.toString() ?? '';
            
//             // Load attribute values
//             final attributes = data['attributesByModelId']?['nodes'] as List<dynamic>?;
//             if (attributes != null) {
//               for (var attr in attributes) {
//                 final a = attr as Map<String, dynamic>;
//                 final def = a['attributeDefinitionByAttributeDefinitionId'] as Map<String, dynamic>?;
//                 final key = def?['key']?.toString();
//                 if (key != null) {
//                   _attributeValues[key] = a['valueText'] ?? 
//                                           a['valueNumber'] ?? 
//                                           a['valueBool'] ?? 
//                                           a['valueTime'];
//                 }
//               }
//             }
//             setState(() {});
//           }
//         });
//       });
//     }
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _descriptionController.dispose();
//     super.dispose();
//   }

//   Future<void> _save() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }

//     final client = ref.read(graphqlClientProvider);
//     final isEditing = widget.modelId != null;
//     int? modelTypeId = widget.modelTypeId;
    
//     if (modelTypeId == null && widget.modelId != null) {
//       final modelAsync = ref.read(modelProvider(widget.modelId!));
//       await modelAsync.whenData((model) {
//         modelTypeId = model?['modelTypeId'] as int?;
//       });
//     }

//     if (modelTypeId == null) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Model type ID is required')),
//         );
//       }
//       return;
//     }

//     try {
//       if (isEditing) {
//         final result = await client.mutate(
//           MutationOptions(
//             document: gql(updateModelMutation),
//             variables: {
//               'id': widget.modelId,
//               'patch': {
//                 'name': _nameController.text,
//                 'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
//               },
//             },
//           ),
//         );

//         if (result.hasException) {
//           print('❌ Mutation Error in updateModelById:');
//           print('Exception: ${result.exception}');
//           if (result.exception?.graphqlErrors != null) {
//             for (var error in result.exception!.graphqlErrors) {
//               print('  - ${error.message}');
//               if (error.extensions != null) {
//                 print('    Extensions: ${error.extensions}');
//               }
//             }
//           }
//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('Error: ${result.exception}')),
//             );
//           }
//           return;
//         }
//       } else {
//         final result = await client.mutate(
//           MutationOptions(
//             document: gql(createModelMutation),
//             variables: {
//               'input': {
//                 'model': {
//                   'name': _nameController.text,
//                   'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
//                   'modelTypeId': modelTypeId,
//                 },
//               },
//             },
//           ),
//         );

//         if (result.hasException) {
//           print('❌ Mutation Error in createModel:');
//           print('Exception: ${result.exception}');
//           if (result.exception?.graphqlErrors != null) {
//             for (var error in result.exception!.graphqlErrors) {
//               print('  - ${error.message}');
//               if (error.extensions != null) {
//                 print('    Extensions: ${error.extensions}');
//               }
//             }
//           }
//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('Error: ${result.exception}')),
//             );
//           }
//           return;
//         }
//       }

//       // Invalidate providers
//       final finalModelTypeId = modelTypeId;
//       if (finalModelTypeId != null) {
//         ref.invalidate(modelsProvider(finalModelTypeId));
//       }
//       if (widget.modelId != null) {
//         ref.invalidate(modelProvider(widget.modelId!));
//       }

//       if (mounted) {
//         Navigator.pop(context);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(isEditing ? 'Model updated' : 'Model created')),
//         );
//       }
//     } catch (e, stackTrace) {
//       print('❌ Exception in model_form_screen._save:');
//       print('Error: $e');
//       print('Stack trace: $stackTrace');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error: $e')),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final modelTypeId = widget.modelTypeId;
    
//     if (modelTypeId == null && widget.modelId == null) {
//       return const Scaffold(
//         body: Center(child: Text('Model type ID is required')),
//       );
//     }
    
//     // If editing and modelTypeId not provided, we'll need to load it
//     int? effectiveModelTypeId = modelTypeId;
//     if (effectiveModelTypeId == null && widget.modelId != null) {
//       return Consumer(
//         builder: (context, ref, child) {
//           final modelAsync = ref.watch(modelProvider(widget.modelId!));
//           return modelAsync.when(
//             data: (model) {
//               effectiveModelTypeId = model?['modelTypeId'] as int?;
//               if (effectiveModelTypeId == null) {
//                 return const Scaffold(
//                   body: Center(child: Text('Model type ID is required')),
//                 );
//               }
//               return _buildForm(context, ref, effectiveModelTypeId!);
//             },
//             loading: () => const Scaffold(
//               body: Center(child: CircularProgressIndicator()),
//             ),
//             error: (error, stack) => Scaffold(
//               body: Center(child: Text('Error: $error')),
//             ),
//           );
//         },
//       );
//     }
    
//     if (effectiveModelTypeId == null) {
//       return const Scaffold(
//         body: Center(child: Text('Model type ID is required')),
//       );
//     }
    
//     return _buildForm(context, ref, effectiveModelTypeId);
//   }
  
//   Widget _buildForm(BuildContext context, WidgetRef ref, int modelTypeId) {

//     final attributeDefinitionsAsync = ref.watch(attributeDefinitionsProvider(modelTypeId));

//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => context.pop(),
//         ),
//         title: Text(widget.modelId == null ? 'Create Model' : 'Edit Model'),
//       ),
//       body: Form(
//         key: _formKey,
//         child: ListView(
//           padding: const EdgeInsets.all(16),
//           children: [
//             TextFormField(
//               controller: _nameController,
//               decoration: const InputDecoration(
//                 labelText: 'Name',
//                 border: OutlineInputBorder(),
//               ),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'Please enter a name';
//                 }
//                 return null;
//               },
//             ),
//             const SizedBox(height: 16),
//             TextFormField(
//               controller: _descriptionController,
//               decoration: const InputDecoration(
//                 labelText: 'Description',
//                 border: OutlineInputBorder(),
//               ),
//               maxLines: 5,
//             ),
//             const SizedBox(height: 24),
//             attributeDefinitionsAsync.when(
//                 data: (definitions) {
//                   if (definitions.isEmpty) {
//                     return const SizedBox.shrink();
//                   }
//                   return Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Attributes',
//                         style: Theme.of(context).textTheme.titleLarge,
//                       ),
//                       const SizedBox(height: 16),
//                       ...definitions.map((def) {
//                         final d = def as Map<String, dynamic>;
//                         final key = d['key']?.toString() ?? '';
//                         return Padding(
//                           padding: const EdgeInsets.only(bottom: 16),
//                           child: AttributeField(
//                             key: ValueKey(d['id']?.toString() ?? ''),
//                             attributeKey: key,
//                             valueType: d['valueType']?.toString() ?? 'string',
//                             value: _attributeValues[key],
//                             required: d['required'] == true,
//                             onChanged: (value) {
//                               setState(() {
//                                 _attributeValues[key] = value;
//                               });
//                             },
//                           ),
//                         );
//                       }).toList(),
//                     ],
//                   );
//                 },
//                 loading: () => const CircularProgressIndicator(),
//                 error: (error, stack) => Text('Error loading attributes: $error'),
//               ),
//             const SizedBox(height: 24),
//             ElevatedButton(
//               onPressed: _save,
//               child: const Text('Save'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

