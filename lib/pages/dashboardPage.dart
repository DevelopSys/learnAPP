import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:learnapp/main.dart';
import 'package:learnapp/pages/AnexosPage.dart';
import 'package:learnapp/pages/alumnosPage.dart';
import 'package:learnapp/pages/empresaPage.dart';
import 'package:learnapp/pages/loginPageState.dart';
import 'package:learnapp/pages/practicasPage.dart';
import 'package:learnapp/pages/resultadosPage.dart';
import 'package:learnapp/pages/tutoresPage.dart';
import 'package:learnapp/pages/settingsPage.dart';

class Maindashboard extends StatefulWidget {
  const Maindashboard({super.key});

  @override
  State<Maindashboard> createState() => _MainPageState();
}

class _MainPageState extends State<Maindashboard> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  int selectedIndex = 0;
  String jwt = 'Cargando token...';
  late String usernname;
  late String role;
  late bool isAdmin;

  final List<String> titles = [
    'Inicio',
    'Alumnos',
    "Resultados",
    'Empresas',
    'Tutores',
    'Prácticas',
    'Anexos',

  ];

  @override
  void initState() {
    super.initState();
    cargarJwt();
  }

  Future<void> cargarJwt() async {
    final token = await secureStorage.read(key: 'jwt');

    setState(() {
      jwt = token ?? 'No hay JWT guardado';
    });

    final url = Uri.parse('http://localhost:8080/api/auth/me');

    var meResponse = await http.get(
      Uri.parse('$url'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('JWT del usuario: $token');
    final data = jsonDecode(meResponse.body);

    setState(() {
      usernname =  data["username"];
      role = data["role"];
      isAdmin = role == 'ADMIN';
    });
  }

  void selectPage(int index) {
    setState(() {
      selectedIndex = index;
    });
    Navigator.pop(context);
  }

  Future<void> logout() async {
    await secureStorage.delete(key: 'jwt');

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPageST()),
      (route) => false,
    );
  }

  Color headerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF11141B)
        : const Color(0xFFF1F5F9);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> pages = [
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'JWT del usuario',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SelectableText(jwt, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
      AlumnosPage(jwt: jwt,),
      EmpresasPage(jwt: jwt,),
      ResultadosAprendizajePage(jwt: jwt,),
      TutoresPage(jwt: jwt),
PracticasPage(jwt: jwt),
      AnexosEmpresasPage(jwt: jwt)

    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Configuración general',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InfoCoursePage(jwt: jwt),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            onPressed: () {
              MyApp.of(context).toggleTheme();
            },
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).drawerTheme.backgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: headerColor(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    child: Icon(Icons.person, color: Colors.black, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mi aplicación',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    usernname,
                    style: TextStyle(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Inicio'),
              selected: selectedIndex == 0,
              onTap: () => selectPage(0),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Alumnos'),
              enabled: isAdmin,
              selected: selectedIndex == 1,
              onTap: () => selectPage(1),
            ),
            ListTile(
              leading: const Icon(Icons.work),
              title: const Text('Empresas'),
              selected: selectedIndex == 2,
              onTap: () => selectPage(2),
            ),
            ListTile(
              leading: const Icon(Icons.work),
              title: const Text('Resultados'),
              selected: selectedIndex == 3,
              onTap: () => selectPage(3),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Tutores'),
              selected: selectedIndex == 4,
              onTap: () => selectPage(4),
            ),
            ListTile(
              leading: const Icon(Icons.newspaper),
              title: const Text('Practicas'),
              selected: selectedIndex == 5,
              onTap: () => selectPage(5),
            ),
            ListTile(
              leading: const Icon(Icons.newspaper),
              title: const Text('Anexos'),
              selected: selectedIndex == 6,
              onTap: () => selectPage(6),
            ),

          ],
        ),
      ),
      body: pages[selectedIndex],
    );
  }
}
