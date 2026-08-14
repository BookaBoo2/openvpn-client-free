/// Короткие русские подписи для UI.
library;

String stageLabelRu(String stage) {
  switch (stage.toLowerCase()) {
    case 'connected':
      return 'Подключено';
    case 'disconnected':
      return 'Отключено';
    case 'connecting':
      return 'Подключение…';
    case 'disconnecting':
      return 'Отключение…';
    case 'authenticating':
    case 'authentication':
      return 'Аутентификация…';
    case 'wait_connection':
      return 'Ожидание…';
    case 'reconnect':
      return 'Переподключение…';
    case 'no_connection':
      return 'Нет сети';
    case 'prepare':
      return 'Подготовка…';
    case 'denied':
      return 'Отклонено';
    case 'error':
      return 'Ошибка';
    case 'resolve':
      return 'DNS…';
    case 'tcp_connect':
    case 'udp_connect':
      return 'Соединение…';
    case 'assign_ip':
      return 'Назначение IP…';
    case 'get_config':
      return 'Получение конфига…';
    case 'add_routes':
      return 'Маршруты…';
    case 'exiting':
      return 'Завершение…';
    default:
      return stage;
  }
}
