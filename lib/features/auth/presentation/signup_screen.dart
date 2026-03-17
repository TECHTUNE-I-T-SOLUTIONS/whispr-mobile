import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/chronicles.dart';
import '../../../core/theme/app_theme.dart';
import '../auth_service.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _penNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  PostType _selectedContentType = PostType.blog;
  final List<String> _selectedCategories = [];

  final List<String> _availableCategories = [
    'Poetry',
    'Fiction',
    'Non-fiction',
    'Personal',
    'Technology',
    'Lifestyle',
    'Travel',
    'Food',
    'Art',
    'Music',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _penNameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signup(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        penName: _penNameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        contentType: _selectedContentType.name,
        categories: _selectedCategories,
      );

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                IconButton(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.arrow_back),
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Title
                Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: AppTheme.spacingS),

                Text(
                  'Join our community of writers and creators',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),

                const SizedBox(height: AppTheme.spacingXXL),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Pen name field
                TextFormField(
                  controller: _penNameController,
                  decoration: const InputDecoration(
                    labelText: 'Pen Name *',
                    hintText: 'Your unique writing name',
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a pen name';
                    }
                    if (value.length < 3) {
                      return 'Pen name must be at least 3 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Display name field
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name *',
                    hintText: 'How others will see you',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a display name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    hintText: 'At least 8 characters',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Confirm password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password *',
                    hintText: 'Re-enter your password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Content type selection
                Text(
                  'What type of content do you create?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: AppTheme.spacingM),

                Column(
                  children: [
                    ListTile(
                      title: const Text('Blog Posts'),
                      leading: Radio<PostType>(
                        value: PostType.blog,
                        groupValue: _selectedContentType, // ignore: deprecated_member_use
                        onChanged: (value) { // ignore: deprecated_member_use
                          setState(() => _selectedContentType = value!);
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Poems'),
                      leading: Radio<PostType>(
                        value: PostType.poem,
                        groupValue: _selectedContentType, // ignore: deprecated_member_use
                        onChanged: (value) { // ignore: deprecated_member_use
                          setState(() => _selectedContentType = value!);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Categories
                Text(
                  'Select your interests (optional)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: AppTheme.spacingM),

                Wrap(
                  spacing: AppTheme.spacingS,
                  runSpacing: AppTheme.spacingS,
                  children: _availableCategories.map((category) {
                    final isSelected = _selectedCategories.contains(category);
                    return FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategories.add(category);
                          } else {
                            _selectedCategories.remove(category);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Bio field
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio (optional)',
                    hintText: 'Tell us about yourself...',
                    prefixIcon: Icon(Icons.info_outlined),
                  ),
                ),

                const SizedBox(height: AppTheme.spacingXXL),

                // Signup button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Create Account'),
                  ),
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}