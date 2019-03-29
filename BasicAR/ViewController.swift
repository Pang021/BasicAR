//
//  ViewController.swift
//  BasicAR
//
//  Created by pangthunyalak on 28/3/2562 BE.
//  Copyright © 2562 pangthunyalak. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import PlacenoteSDK

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, PNDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    @IBAction func Action(_ sender: Any) {
        
        // put this within your buttons IBAction
        LibPlacenote.instance.startSession()
        renderSphere()
        placenoteSessionRunning = true
        
    }
    
    @IBAction func loadMap(_ sender: Any) {
        // start mapping session.
        if (!placenoteSessionRunning)
        {
            placenoteSessionRunning = true
            renderSphere()
            LibPlacenote.instance.startSession()
        }
        else
        {
            placenoteSessionRunning = false
            
            //save the map and stop session
            LibPlacenote.instance.saveMap(savedCb: { (mapID: String?) -> Void in
                print ("MapId: " + mapID!)
                LibPlacenote.instance.stopSession()  },
                                          
                                          uploadProgressCb: {(completed: Bool, faulted: Bool, percentage: Float) -> Void in
                                            print("Map Uploading...")
                                            if(completed){
                                                print("Map upload done!!!")
                                            }
            })
        }
    }
    
    @IBAction func saveMap(_ sender: Any) {
        if (!placenoteSessionRunning)
        {
            placenoteSessionRunning = true
            LibPlacenote.instance.loadMap(mapId: "Paste Map ID here",
                                          downloadProgressCb: {(completed: Bool, faulted: Bool, percentage: Float) -> Void in
                                            if (completed) {
                                                LibPlacenote.instance.startSession()
                                            }
            })
        }
    }
    
    
    let planeGeometry = SCNPlane()
    //Initialize the camManager variable in your class
    private var camManager: CameraManager? = nil;
    private var ptViz: FeaturePointVisualizer? = nil;
    private var placenoteSessionRunning: Bool = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // configuration
        LibPlacenote.instance.multiDelegate += self
        
        // set up AR session
        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
        sceneView.session.delegate = self
        
        ptViz = FeaturePointVisualizer(inputScene: sceneView.scene);
        ptViz?.enableFeaturePoints()
        
        if let camera: SCNNode = sceneView?.pointOfView {
            camManager = CameraManager(scene: sceneView.scene, cam: camera)
        }
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        planeGeometry.materials.first?.diffuse.contents = UIColor.yellow.withAlphaComponent(0.8)
        
        let planeNode = SCNNode(geometry: planeGeometry)
        
        // send AR frame to placenote
        func session(_ session: ARSession, didUpdate: ARFrame) {
            
            let image: CVPixelBuffer = didUpdate.capturedImage
            let pose: matrix_float4x4 = didUpdate.camera.transform
            
            if (placenoteSessionRunning) {
                LibPlacenote.instance.setFrame(image: image, pose: pose)
                //print("sent placenote a frame")
            }
        }

    }
    // Create a sphere at (0,0,0) and apply a diffuse green color to it
    func renderSphere() {
        let geometry:SCNGeometry = SCNSphere(radius: 0.05) //units, meters
        let geometryNode = SCNNode(geometry: geometry)
        geometryNode.position = SCNVector3(x:0.0, y:0.0, z:0.0)
        geometryNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        sceneView.scene.rootNode.addChildNode(geometryNode)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Run the view's session
        sceneView.delegate = self
        
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        
        if let camera = sceneView.pointOfView?.camera {
            camera.wantsHDR = true
            camera.exposureOffset = -1
            camera.minimumExposure = -1
            camera.maximumExposure = 3
        }
        
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    var plane: SCNNode?
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        if let planeAnchor = anchor as? ARPlaneAnchor {
            
            planeGeometry.width = CGFloat(planeAnchor.extent.x)
            planeGeometry.height = CGFloat(planeAnchor.extent.z)
        
            plane?.removeFromParentNode()
            plane = SCNNode(geometry: planeGeometry)
            plane?.transform = SCNMatrix4MakeRotation(Float(-Double.pi / 2.0), 1.0, 0.0, 0.0)
         
            node.addChildNode(plane!)
        }
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
         if let planeAnchor = anchor as? ARPlaneAnchor {
            
            planeGeometry.width = CGFloat(planeAnchor.extent.x)
            planeGeometry.height = CGFloat(planeAnchor.extent.z)
            plane?.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z);
        }
        
    }
    
    ///TabGesture
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        let touch = touches.first
        let location = touch?.location(in: sceneView)
        
        let hitResults = sceneView.hitTest(location!, types: .featurePoint)
        
        if let hitTestResult = hitResults.first {
            let transform = hitTestResult.worldTransform
            let positionTwo = SCNVector3(x: transform.columns.3.x, y: transform.columns.3.y, z:transform.columns.3.z)
            
            let geometry: SCNGeometry
            geometry = SCNPyramid(width:1.0, height:1.0, length:1.0)
            geometry.materials.first?.diffuse.contents = UIColor.red
            
            
            let geometryNode = SCNNode(geometry: geometry)
            geometryNode.position = positionTwo
            print("Object Position : \(positionTwo)")
            geometryNode.scale = SCNVector3(x:0.1, y:0.1, z:0.1)
            
            sceneView.scene.rootNode.addChildNode(geometryNode)
            
        }
        
    }
    
    
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    

    //Receive a pose update when a new pose is calculated
    func onPose(_ outputPose: matrix_float4x4, _ arkitPose: matrix_float4x4) {
        
    }
    
    //Receive a status update when the status changes
    func onStatusChange(_ prevStatus: LibPlacenote.MappingStatus, _ currStatus: LibPlacenote.MappingStatus) {
        if (prevStatus == LibPlacenote.MappingStatus.lost && currStatus == LibPlacenote.MappingStatus.running) {
            renderSphere()
            print("Map Found!")
        }
    }
    private func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}
