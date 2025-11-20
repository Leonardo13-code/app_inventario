// lib/auth/login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Mantener para el error handling específico
import 'package:InVen/services/auth_service.dart'; // Importar el servicio

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService(); // Instancia del servicio
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Para validación del formulario
  bool isLogin = true;
  bool _isLoading = false; // Estado para el indicador de carga

  Future<void> _handleAuth() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Mostrar indicador de carga
      });
      try {
        if (isLogin) {
          await _authService.signInWithEmail(
            emailController.text.trim(),
            passwordController.text.trim(),
          );
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Registro exitoso")),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        // Manejo específico de errores de Firebase Auth
        String errorMessage;
        if (e.code == 'user-not-found') {
          errorMessage = 'No se encontró ningún usuario con ese correo.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Contraseña incorrecta.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'El correo ya está en uso.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'La contraseña es demasiado débil.';
        } else {
          errorMessage = 'Error de autenticación: ${e.message}';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } catch (e) {
        // Otros errores generales
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${e.toString()}")),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false; // Ocultar indicador de carga
          });
        }
      }
    }
  }

  Future<void> _resetPassword() async {
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, introduce tu correo para restablecer la contraseña.")),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      await _authService.resetPassword(emailController.text.trim()); // Método a añadir en AuthService
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Se ha enviado un correo de restablecimiento a ${emailController.text.trim()}")),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al restablecer contraseña: ${e.message}';
      if (e.code == 'user-not-found') {
        errorMessage = 'No se encontró ningún usuario con ese correo.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      appBar: AppBar(
        title: Text(isLogin ? "Iniciar Sesión" : "Registrarse"),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SafeArea(
        child: Center( 
          child: ConstrainedBox( 
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Para que la columna ocupe el mínimo espacio
                      children: [
                        Text(
                          isLogin ? "Bienvenido de nuevo" : "Crea una cuenta",
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 30),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: "Correo electrónico",
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingresa tu correo';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: passwordController,
                          decoration: const InputDecoration(
                            labelText: "Contraseña",
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.done, // Muestra botón de "Check" en teclado móvil
                          onFieldSubmitted: (value) => _handleAuth(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingresa tu contraseña';
                            }
                            if (value.length < 6 && !isLogin) { // Solo si es registro
                              return 'La contraseña debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _isLoading
                            ? const CircularProgressIndicator() // Indicador de carga
                            : ElevatedButton(
                                onPressed: _handleAuth,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50), // Botón de ancho completo
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  isLogin ? "Iniciar Sesión" : "Registrar",
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isLogin = !isLogin;
                              _formKey.currentState?.reset(); // Limpiar validaciones al cambiar
                            });
                          },
                          child: Text(
                            isLogin
                                ? "¿No tienes cuenta? Regístrate"
                                : "¿Ya tienes cuenta? Inicia sesión",
                            style: TextStyle(color: Theme.of(context).primaryColor),
                          ),
                        ),
                        if (isLogin) // Mostrar opción de restablecer solo en la vista de login
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