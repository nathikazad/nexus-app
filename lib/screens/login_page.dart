import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_voice_assistant/auth.dart';
import 'package:nexus_voice_assistant/db.dart';

/// Login page with fields for userId and endpoint.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _endpointController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set default endpoint
    _userIdController.text = GraphQLConfig.defaultUserId;
    _endpointController.text = GraphQLConfig.defaultEndpoint;
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final userId = _userIdController.text.trim();
      final endpoint = _endpointController.text.trim();
      
      final errorMessage = await ref.read(authProvider.notifier).login(userId, endpoint);
      
      // If login succeeded (null), router will automatically redirect to home
      if (errorMessage == null) return;
      
      // Show error message if login failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nexus Navigator',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _userIdController,
                  decoration: const InputDecoration(
                    labelText: 'User ID',
                    hintText: '1',
                    border: OutlineInputBorder(),
                    helperText: 'User ID to send in x-user-id header',
                  ),
                  keyboardType: TextInputType.text,
                  enabled: !isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'User ID is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _endpointController,
                  decoration: const InputDecoration(
                    labelText: 'GraphQL Endpoint',
                    hintText: 'http://localhost:5001/graphql',
                    border: OutlineInputBorder(),
                    helperText: 'The URL of your GraphQL server',
                  ),
                  keyboardType: TextInputType.url,
                  enabled: !isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Endpoint is required';
                    }
                    if (!value.startsWith('http://') && !value.startsWith('https://')) {
                      return 'Endpoint must start with http:// or https://';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
                if (authState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Error: ${authState.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

