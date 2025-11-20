// lib/auth/login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:InVen/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool isLogin = true;
  bool _isLoading = false;
  bool _rememberEmail = false; 
  bool _obscurePassword = true;

  // Color principal
  final Color _primaryColor = const Color(0xFF00508C);

  @override
  void initState() {
    super.initState();
    _loadSavedEmail(); 
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedEmail = prefs.getString('saved_email');
    
    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        emailController.text = savedEmail;
        _rememberEmail = true; 
      });
    }
  }

  Future<void> _handleRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberEmail) {
      await prefs.setString('saved_email', emailController.text.trim());
    } else {
      await prefs.remove('saved_email');
    }
  }

  Future<void> _handleAuth() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        if (isLogin) {
          await _authService.signInWithEmail(
            emailController.text.trim(),
            passwordController.text.trim(),
          );
          await _handleRememberMe();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Inicio de sesión exitoso")),
            );
          }
        } else {
          await _authService.createUserWithEmail(
            emailController.text.trim(),
            passwordController.text.trim(),
          );
          await _handleRememberMe();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Cuenta creada exitosamente")),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Error de autenticación';
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          errorMessage = 'Credenciales incorrectas.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Contraseña incorrecta.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'El correo ya está registrado.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'La contraseña es muy débil.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa tu correo para recuperar la clave.")),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.resetPassword(emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Correo enviado a ${emailController.text.trim()}"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Fondo gris muy suave (limpio)
      appBar: AppBar(
        title: Text(isLogin ? "Iniciar Sesión" : "Registrarse"),
        centerTitle: true,
        backgroundColor: _primaryColor,
        elevation: 0, // Sin sombra para un look más plano y limpio
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            // Mantiene el ancho controlado en PC/Web (NO ESTIRADO)
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              elevation: 4, // Sombra suave clásica
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Título simple y limpio
                        Text(
                          isLogin ? "Bienvenido de nuevo" : "Crear Cuenta",
                          style: TextStyle(
                            fontSize: 24, 
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800]
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // CAMPO EMAIL
                        TextFormField(
                          controller: emailController,
                          autofillHints: const [AutofillHints.email],
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: "Correo electrónico",
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(), // Borde clásico
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (v) => v!.isEmpty ? 'Ingresa tu correo' : null,
                        ),
                        const SizedBox(height: 20),
                        
                        // CAMPO CONTRASEÑA
                        TextFormField(
                          controller: passwordController,
                          autofillHints: const [AutofillHints.password],
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleAuth(),
                          decoration: InputDecoration(
                            labelText: "Contraseña",
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(), // Borde clásico
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                            if (!isLogin && v.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                        ),
                        
                        // CHECKBOX Y OLVIDASTE CLAVE
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberEmail,
                              activeColor: _primaryColor,
                              onChanged: (v) => setState(() => _rememberEmail = v ?? false),
                            ),
                            const Text("Recordar correo"),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // BOTÓN PRINCIPAL
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: _handleAuth,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    isLogin ? "INICIAR SESIÓN" : "REGISTRARME",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // ENLACES DE TEXTO (LIMPIOS)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isLogin = !isLogin;
                              _formKey.currentState?.reset();
                              passwordController.clear();
                            });
                          },
                          child: Text(
                            isLogin
                                ? "¿No tienes cuenta? Regístrate"
                                : "¿Ya tienes cuenta? Inicia sesión",
                            style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600),
                          ),
                        ),
                        
                        if (isLogin)
                          TextButton(
                            onPressed: _resetPassword,
                            child: Text(
                              "¿Olvidaste tu contraseña?",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}