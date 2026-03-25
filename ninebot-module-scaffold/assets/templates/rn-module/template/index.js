import { AppRegistry } from 'react-native';
import { initApp } from '@ninebot/rn-core';
import routes from './routes';
import { name as appName } from './module.json';

AppRegistry.registerComponent(appName, () => initApp(routes, [], {}));
