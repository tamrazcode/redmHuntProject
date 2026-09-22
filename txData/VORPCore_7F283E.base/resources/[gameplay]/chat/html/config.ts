export default {
  defaultTemplateId: 'default',
  defaultAltTemplateId: 'defaultAlt',
  templates: {
    'default': '<b>{0}</b>: {1}',
    'defaultAlt': '{0}',
    'print': '<pre>{0}</pre>',
    'example:important': '<h1>^2{0}</h1>'
  },
  fadeTimeout: 3000, // 3 секунды до исчезновения
  suggestionLimit: 5,
  style: {
    background: 'rgba(10, 10, 14, 0.78)',
    width: '38vw',
    height: '22%',
  }
};
