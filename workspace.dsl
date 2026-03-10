workspace "Вариант 14 - Фитнес-трекер" "Задание №1. Документирование архитектуры в Structurizr" {

  model {
    properties {
      "structurizr.groupSeparator" "/"
    }

    user = person "Пользователь" "Создаёт тренировки, добавляет упражнения, смотрит историю и статистику." "Person"
    admin = person "Администратор" "Поддержка пользователей и модерация справочника упражнений (опционально)." "Person"

    notificationProvider = softwareSystem "Notification Provider" "Внешний сервис отправки Email/SMS/Push." "External"
    idp = softwareSystem "Identity Provider" "Внешний OAuth2/OIDC провайдер (SSO/логин)." "External"

    fitness = softwareSystem "Fitness Tracker" "Система учёта тренировок и упражнений." {
      tags "Software System"

      webapp = container "Web App" "Веб-клиент (SPA) для пользователей и администраторов." "Web Application (SPA)"
      mobileapp = container "Mobile App" "Мобильный клиент (iOS/Android)." "Mobile Application"

      apigw = container "Backend API" "Единая точка входа для клиентов. Маршрутизация запросов к доменным сервисам, авторизация, rate limit." "REST API (HTTPS)"

      auth = container "Auth Service" "Аутентификация/авторизация, интеграция с IdP, выпуск JWT." "Service (OAuth2/OIDC)"
      usersvc = container "User Service" "Пользователи: создание, поиск по логину, поиск по маске ФИО." "Service (REST)"
      exercisesvc = container "Exercise Service" "Справочник упражнений: создание упражнения, список упражнений." "Service (REST)"
      workoutsvc = container "Workout Service" "Тренировки: создание тренировки, добавление упражнения в тренировку, история тренировок." "Service (REST)"
      statssvc = container "Statistics Service" "Агрегация и расчёт статистики тренировок за период." "Service (REST)"
      notifsvc = container "Notification Service" "Формирует и отправляет уведомления во внешний провайдер." "Service (Async worker)"

      broker = container "Message Broker" "Шина событий для асинхронных процессов (уведомления, аудит)." "Kafka/RabbitMQ"
      cache = container "Cache" "Кэш для часто читаемых справочников и профилей." "Redis"

      userdb = container "User DB" "Хранение пользователей и профилей." "PostgreSQL Database"
      exercisedb = container "Exercise DB" "Хранение справочника упражнений." "PostgreSQL Database"
      workoutdb = container "Workout DB" "Хранение тренировок, состава тренировки и метрик." "PostgreSQL Database"

      user -> webapp "Использует" "HTTPS"
      user -> mobileapp "Использует" "HTTPS"
      admin -> webapp "Администрирует/поддержка" "HTTPS"

      webapp -> apigw "Вызывает API" "HTTPS/REST"
      mobileapp -> apigw "Вызывает API" "HTTPS/REST"

      apigw -> auth "Проверка токена/логин" "HTTPS/REST"
      apigw -> usersvc "Операции с пользователями" "HTTPS/REST"
      apigw -> exercisesvc "Операции с упражнениями" "HTTPS/REST"
      apigw -> workoutsvc "Операции с тренировками" "HTTPS/REST"
      apigw -> statssvc "Запрос статистики" "HTTPS/REST"

      auth -> idp "SSO/аутентификация" "OAuth2/OIDC"

      usersvc -> userdb "CRUD" "JDBC"
      exercisesvc -> exercisedb "CRUD" "JDBC"
      workoutsvc -> workoutdb "CRUD" "JDBC"
      statssvc -> workoutdb "Чтение данных тренировок" "JDBC"

      apigw -> cache "Чтение/запись кэша" "Redis protocol"
      usersvc -> cache "Кэш профилей" "Redis protocol"
      exercisesvc -> cache "Кэш справочника" "Redis protocol"

      workoutsvc -> broker "Публикует события (WorkoutCreated/ExerciseAdded)" "AMQP/Kafka protocol"
      notifsvc -> broker "Читает события" "AMQP/Kafka protocol"
      notifsvc -> notificationProvider "Отправка уведомлений" "HTTPS"
    }
  }

  views {
    systemContext fitness "C1-SystemContext" "System Context для фитнес-трекера" {
      include user
      include admin
      include fitness
      include notificationProvider
      include idp
      autolayout lr
    }

    container fitness "C2-Container" "Container диаграмма фитнес-трекера" {
      include *
      autolayout lr
    }

    dynamic fitness "D1-CreateWorkoutAndAddExercise" "Сценарий: создать тренировку и добавить упражнение" {
      user -> mobileapp "1. Заполняет форму тренировки"
      mobileapp -> apigw "2. POST /workouts (создать тренировку)"
      apigw -> auth "3. Проверка JWT"
      auth -> idp "4. (опц.) интроспекция/валидация"
      apigw -> workoutsvc "5. CreateWorkout(userId, date, title)"
      workoutsvc -> workoutdb "6. INSERT workout"
      workoutsvc -> broker "7. Publish WorkoutCreated"

      user -> mobileapp "8. Выбирает упражнение и параметры"
      mobileapp -> apigw "9. POST /workouts/{id}/exercises"
      apigw -> auth "10. Проверка JWT"
      apigw -> exercisesvc "11. ValidateExercise(exerciseId)"
      exercisesvc -> cache "12. (опц.) get exercise from cache"
      exercisesvc -> exercisedb "13. if cache miss: SELECT exercise"
      apigw -> workoutsvc "14. AddExerciseToWorkout(workoutId, exerciseId, sets, reps, duration)"
      workoutsvc -> workoutdb "15. INSERT workout_exercise"
      workoutsvc -> broker "16. Publish ExerciseAdded"
      notifsvc -> broker "17. Consume events"
      notifsvc -> notificationProvider "18. Send notification (workout updated)"
      autolayout lr
    }

    styles {
      element "Person" {
        shape person
      }
      element "External" {
        background "#999999"
        color "#ffffff"
      }
      element "Software System" {
        background "#1168bd"
        color "#ffffff"
      }
      element "Container" {
        background "#438dd5"
        color "#ffffff"
      }
      element "Database" {
        shape cylinder
      }
    }

    theme default
  }
}
