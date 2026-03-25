import React, { useMemo } from 'react';
import {
  SafeAreaView,
  View,
  Text,
  StyleSheet,
} from 'react-native';

const HomeScreen = () => {
  const tips = useMemo(
    () => [
      '修改 src/pages/Home 目录中的文件，开始搭建你的页面',
      '在 routes.js 中配置新的页面路由',
      '通过 src/core 目录中的工具接入业务逻辑',
    ],
    [],
  );

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <View style={styles.header}>
          <Text style={styles.welcome}>欢迎使用</Text>
          <Text style={styles.brand}>九号 React Native 模板工程</Text>
          <Text style={styles.subtitle}>
            这里已经为你准备好了基础依赖与工程结构，助你快速启动跨平台开发。
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>接下来可以做什么？</Text>
          {tips.map((tip, index) => (
            <View key={tip} style={styles.tipRow}>
              <Text style={styles.tipIndex}>{String(index + 1).padStart(2, '0')}</Text>
              <Text style={styles.tipText}>{tip}</Text>
            </View>
          ))}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>常用命令</Text>
          <View style={styles.commandRow}>
            <Text style={styles.command}>yarn install</Text>
            <Text style={styles.commandRemark}>安装依赖</Text>
          </View>
          <View style={styles.commandRow}>
            <Text style={styles.command}>yarn start</Text>
            <Text style={styles.commandRemark}>启动开发服务器</Text>
          </View>
          <View style={styles.commandRow}>
            <Text style={styles.command}>运行App输入模块名</Text>
            <Text style={styles.commandRemark}>开始调试</Text>
          </View>
        </View>

        <View style={styles.footer}>
          <Text style={styles.footerText}>Happy coding!</Text>
        </View>
      </View>
    </SafeAreaView>
  );
};

export default HomeScreen;

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F6F7',
  },
  content: {
    flex: 1,
    paddingHorizontal: 24,
    paddingVertical: 32,
  },
  header: {
    marginBottom: 32,
  },
  welcome: {
    fontSize: 18,
    color: '#5B6573',
    marginBottom: 8,
  },
  brand: {
    fontSize: 26,
    fontWeight: '600',
    color: '#121826',
    marginBottom: 12,
  },
  subtitle: {
    fontSize: 15,
    lineHeight: 22,
    color: '#5B6573',
  },
  section: {
    marginBottom: 32,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#121826',
    marginBottom: 16,
  },
  tipRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  tipIndex: {
    width: 28,
    fontFamily: 'Menlo',
    fontSize: 12,
    color: '#55637A',
    marginRight: 8,
    paddingTop: 2,
  },
  tipText: {
    flex: 1,
    fontSize: 14,
    lineHeight: 20,
    color: '#374151',
  },
  commandRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 10,
  },
  command: {
    fontFamily: 'Menlo',
    fontSize: 13,
    color: '#0B5FFF',
    backgroundColor: '#EAF2FF',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
    marginRight: 12,
  },
  commandRemark: {
    fontSize: 13,
    color: '#5B6573',
  },
  footer: {
    marginTop: 'auto',
    alignItems: 'center',
  },
  footerText: {
    fontSize: 15,
    color: '#5B6573',
  },
});
