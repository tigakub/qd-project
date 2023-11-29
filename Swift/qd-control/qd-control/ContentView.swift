//
//  ContentView.swift
//  qd-control
//
//  Created by Edward Janne on 10/25/23.
//

import SwiftUI
import Network
import simd
import SceneKit

struct ScrollViewOffsetPreferenceKey: SwiftUI.PreferenceKey {
    static var defaultValue: CGPoint { .zero }

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        // No-op
    }
}

struct ScrollViewDeltaPreferenceKey: SwiftUI.PreferenceKey {
    static var defaultValue: CGSize { .zero }

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        // No-op
    }
}

struct ScrollViewFactorPreferenceKey: SwiftUI.PreferenceKey {
    static var defaultValue: CGSize { .zero }

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        // No-op
    }
}

struct ContentView: View {
    @State var feedback = QDFeedback()
    
    @Bindable var qdControl: QDControl
    @Bindable var qdRobot: QDRobot
    @Bindable var qdClient: QDClient
    
    @State var viewPosition: CGPoint = .zero
    @State var mouseLocation: CGPoint = .zero
    
    var body: some View {
        VStack {
            GeometryReader {
                g in
                ScrollViewReader {
                    scrollView in
                    ScrollView([.horizontal, .vertical]) {
                        ZStack {
                            TimelineView(.animation(minimumInterval: 0.033, paused: qdControl.paused)) {
                                timeline in
                                Canvas {
                                    context, size in
                                    qdControl.render(context: &context, size: size)
                                }
                            }
                            GeometryReader {
                                g2 in
                                let g2Frame = g2.frame(in: .named("scroll"))
                                let offset  = g2Frame.origin
                                let delta = CGSize(width: g2.size.width - g.size.width, height: g2.size.height - g.size.height)
                                let factor = CGSize(width: offset.x / delta.width, height: offset.y / delta.height)
                                Color.clear
                                    .preference(key: ScrollViewOffsetPreferenceKey.self, value: offset)
                                    .preference(key: ScrollViewDeltaPreferenceKey.self, value: delta)
                                    .preference(key: ScrollViewFactorPreferenceKey.self, value: factor)
                                
                            }
                        }
                            .frame(width: largerOf(v0: (g.size.width * CGFloat(qdControl.renderScale) * 2.0), v1: 2000.0 * CGFloat(qdControl.renderScale)), height: largerOf(v0: (g.size.height * CGFloat(qdControl.renderScale) * 2.0), v1: 2000.0 * CGFloat(qdControl.renderScale)))
                    }
                        .coordinateSpace(name: "scroll")
                        .onAppear() {
                            viewPosition = CGPoint(x: g.size.width * 0.5, y: g.size.height * 0.5)
							NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) {
								event in
								mouseLocation = event.locationInWindow
								let contentFrame = g.frame(in: .named("content"))
								mouseLocation.x -= contentFrame.minX
								mouseLocation.y -= contentFrame.minY
								// print("\(contentFrame) \(mouseLocation)")
								return event
							}
                        }
                        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) {
                            value in
                            // print("offset: \(value)")
                            viewPosition = CGPoint(x: -value.x + g.size.width * 0.5, y: -value.y + g.size.height * 0.5)
                        }
                        .onPreferenceChange(ScrollViewDeltaPreferenceKey.self) {
                            value in
                            // print("delta: \(value)")
                        }
                        .onPreferenceChange(ScrollViewFactorPreferenceKey.self) {
                            value in
                            // print("factor: \(value)")
                        }
                        .border(Color.black)
                }
            }
			
            HStack {
                Button {
					qdControl.restart()
				} label: {
					Text("Restart")
				}
				
                Button {
                    qdControl.paused.toggle()
                } label: {
                    Text(qdControl.paused ? "Unpause" : "Pause")
                }
                
                Slider(value: $qdControl.renderScale, in: 0.1 ... 10.0)
            }
			
			Slider(value: $qdControl.pathSlider, in: 0.0 ... 1.1)
			
			HStack {
				Text("\(qdControl.firstBell)")
				Text("\(qdControl.secondBell)")
			}
        }
            .padding()
			.coordinateSpace(name: "content")
			.onAppear {
				qdClient.start {
					cnx in
					cnx.receiveMessage {
						data, contentContext, isComplete, error in
						if let data = data {
							let decoder = QDDecoder(source: data)
							feedback = decoder.decode(QDFeedback.self)
						}
					}
				}
			}
    }
}

/*
#Preview {
    ContentView(pose: qdPose)
}
*/
