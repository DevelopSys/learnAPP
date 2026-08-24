class ApiConfig {
  static const String baseUrl =
  'https://learnback-c8vp.onrender.com';
      /*'http://localhost:8080';*/
  /*Actualizacion realizada para la gestion de ciclos*/

  static const String apiPrefix = '/api';

  static String get fullBaseUrl =>
      '$baseUrl$apiPrefix';

  // Autenticación
  static String get authLogin =>
      '$fullBaseUrl/auth/login';

  static String get authRegister =>
      '$fullBaseUrl/auth/register';

  static String get authGoogleLink =>
      '$fullBaseUrl/auth/google/link';

  static String get authMe =>
      '$fullBaseUrl/auth/me';

  // Dashboard
  static String get homeStudents =>
      '$fullBaseUrl/home/students';

  // Cursos
  static String get courses =>
      '$fullBaseUrl/courses';

  static String get publicCourses =>
      '$fullBaseUrl/public/courses';


  // Alumnos
  static String get students =>
      '$fullBaseUrl/students';

  static String get studentsUpload =>
      '$fullBaseUrl/students/upload';

  static String get studentsTemplate =>
      '$fullBaseUrl/students/template';

  // Empresas

  static String get companies =>
      '$fullBaseUrl/companies';

  static String get companiesAll =>
      '$fullBaseUrl/companies/all';

  static String get companiesUpload =>
      '$fullBaseUrl/companies/upload';

  static String get companiesTemplate =>
      '$fullBaseUrl/companies/template';

  // Tutores
  static String get trainees =>
      '$fullBaseUrl/trainees';

  // Prácticas
  static String get practices =>
      '$fullBaseUrl/practices';

  // Convenios y anexos
  static String get agreements =>
      '$fullBaseUrl/agreements';

  // Resultados de aprendizaje
  static String get learningResults =>
      '$fullBaseUrl/learning-results';

  static String get learningResultsUpload =>
      '$fullBaseUrl/learning-results/upload';

  static String get learningResultsTemplate =>
      '$fullBaseUrl/learning-results/template';

  // Información del centro
  static String get infoCourses =>
      '$fullBaseUrl/info-courses';

  // Administración de usuarios
  static String get adminUsers =>
      '$fullBaseUrl/admin/users';


}
