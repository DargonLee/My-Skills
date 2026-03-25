import I18nClass from '@ninebot/rn-core';
import defaultLang from './lang';

let instance;

function getInstance() {
  if (!instance) {
    instance = new I18nClass(defaultLang);
  }
  return instance;
}

export function getI18nString(str, ...p) {
  return getInstance().getI18n(str, [...p]);
}

export function I18nText(props) {
  return getInstance().getI18nText(props.i18n, props.children);
}
