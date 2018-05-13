import React, { Component } from 'react';
import { Platform, StyleSheet, Text, View, Image, TouchableHighlight } from 'react-native';
import FegoRNUpdate from 'fego-rn-update'

export default class App extends Component {
	render() {
		return (
			<View style={styles.container}>
				<View style={styles.box}>
					<Text>图片更新测试</Text>
					<Image source={require('./img/app.png')} style={{ width: 50, height: 59 }} />
				</View>
				<View style={styles.box}>
					<Text>字体更新测试</Text>
					<Text style={[styles.welcome, { fontFamily: 'iconfont' }]}>&#xe60d;</Text>
				</View>
				<View style={styles.box}>
					<Text>内容更新测试</Text>
					<Text style={styles.welcome}>Welcome to FegoRNUpdate-000000!</Text>
				</View>
				<TouchableHighlight
					underlayColor="transparent"
					onPress={() => {
						FegoRNUpdate.hotReload();
					}}>
					<Text style={styles.btnText}>热更新测试</Text>
				</TouchableHighlight>
			</View>
		);
	}
}

const styles = StyleSheet.create({
	container: {
		flex: 1,
		justifyContent: 'center',
		backgroundColor: '#F5FCFF',
	},
	welcome: {
		fontSize: 20,
		textAlign: 'center',
		margin: 10,
	},
	box: {
		borderWidth: 1,
		borderColor: 'red',
		margin: 10,
		padding: 10,
	},
	btnText: {
		color: 'blue',
		fontSize: 16,
		textAlign: 'center',
		borderWidth: 1,
		borderColor: 'blue',
		borderRadius: 10,
		height: 30,
		padding: 6,
	}
});
