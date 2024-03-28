//
//  main.swift
//  com.metacubex.ClashX.ProxyConfigHelper


import Foundation

ProcessInfo.processInfo.disableSuddenTermination()
let helper = ProxyConfigHelper()
helper.run()

print("ProxyConfigHelper exit")
