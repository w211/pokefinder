//
//  ViewController.swift
//  pokefinder
//
//  Created by Richard Cuico on 11/23/16.
//  Copyright © 2016 Richard Cuico. All rights reserved.
//

import UIKit
import MapKit
import FirebaseDatabase

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    let locationManager = CLLocationManager()
    var mapHasCenteredOnce = false
    
    var geoFire: GeoFire!
    var geoFireRef: FIRDatabaseReference!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
  
        mapView.delegate = self
        mapView.userTrackingMode = MKUserTrackingMode.follow
        
        geoFireRef = FIRDatabase.database().reference()
        geoFire = GeoFire(firebaseRef: geoFireRef)
        
    }

    override func viewDidAppear(_ animated: Bool) {
        locationAuthStatus()
    }
    
    func locationAuthStatus () {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        if status == CLAuthorizationStatus.authorizedWhenInUse {
            mapView.showsUserLocation = true
        }
    }
    
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 2000, 2000)
    
        mapView.setRegion(coordinateRegion, animated: true)
    
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        
        if let loc = userLocation.location {
            
            if !mapHasCenteredOnce {
                centerMapOnLocation(location: loc)
                mapHasCenteredOnce = true
            }
        }
    }
    
    //This creates a sighting and puts it on the map
    // 4) THE VIEW for Annotation is going to called
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        //Here we create an Identifier for the pokemon
        let annoIdentifier = "Pokemon"
        var annotationView: MKAnnotationView?
        
        // If it's a user use the ASH location
        if annotation.isKind(of: MKUserLocation.self) {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "User")
            annotationView?.image = UIImage(named: "ash")
        
        //Otherwise try to deque a reuseable cell with the information already in it
        //If that isnt possible
        } else if let deqAnno = mapView.dequeueReusableAnnotationView(withIdentifier: annoIdentifier) {
            annotationView = deqAnno
            annotationView?.annotation = annotation
        
        //Create a defualt one
        } else {
            let av = MKAnnotationView(annotation: annotation, reuseIdentifier: annoIdentifier)
            av.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            annotationView = av
        }
        
        //And then in any of the cases lets go ahead and customize it 
        
        if let annotationView = annotationView, let anno = annotation as? PokeAnnotation {
        
            //By giving it the image itself on the annotation itself by giving it a pokemon
            //And then we want to set the canShowCallout when you tap on it shows
            //The map picture in Assets
            
            annotationView.canShowCallout = true
            annotationView.image = UIImage(named: "\(anno.pokemonNumber)")
            
            //And then what we want to do is create a button and set the frame of it
            //And then give it the image of the map
            //and the rightCalloutAccessoryView
            let btn = UIButton()
            btn.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            btn.setImage(UIImage(named: "map"), for: .normal)
            annotationView.rightCalloutAccessoryView = btn
        
        }
        
        //and then we return it and it'll show up on the map
        return annotationView
        
    }
    
    // 2)
    func createSighting(forLocation location: CLLocation, withPokemon pokeId: Int) {
        
        //When this happens and you set something
        geoFire.setLocation(location, forKey: "\(pokeId)")
        
    }
    
    // 3) This starts happening
    func showSightingsOnMap(location: CLLocation) {
        let circleQuery = geoFire!.query(at: location, withRadius: 2.5)
        
        //This call back right here is going to be called automatically 
        //.keyEntered
        //So anytime you add a new pokemon it's going to call this and add it onto the map
        
        //Also when the the app first loads for the first time
        //This entire function is going to be called and cycle through for every single pokemon
        //On the map in a specific geographical location
        //And it's going to add it as an Annotation
        // AND THEN
        
        _ = circleQuery?.observe(GFEventType.keyEntered, with: { (key, location) in
            
            if let key = key, let location = location {
                let anno = PokeAnnotation(coordinate: location.coordinate, pokemonNumber: Int(key)!)
                self.mapView.addAnnotation(anno)
            }
            
        })
    }
  
    //This is being included so that when you zoom out you'll see more pokemon instead of just 2.5 kilometers away from you
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        
        //This grabs the center of the map whereever the user is scrolling
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        
        showSightingsOnMap(location: loc)
        
    }
    
    //Here we want the map in the popup from clicking on the marker to do something
    //This is what happens after we tap on the map
    //We want to get the pokemon's location and show appleMaps and show traveling directions
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        if let anno = view.annotation as? PokeAnnotation {
            let place = MKPlacemark(coordinate: anno.coordinate)
            let destination = MKMapItem(placemark: place)
            destination.name = "Pokemon Sighting"
            let regionDistance: CLLocationDistance = 1000
            let regionSpan = MKCoordinateRegionMakeWithDistance(anno.coordinate, regionDistance, regionDistance)
            
            let options = [MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center), MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span), MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving] as [String : Any]
            
            MKMapItem.openMaps(with: [destination], launchOptions: options)
        }
        
    }
    
    
    // 1) If you spot a random Pokemon it'll call createSighting
    @IBAction func spotRandomPokemon(_ sender: Any) {
    
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        
        let rand = arc4random_uniform(151) + 1
        createSighting(forLocation: loc, withPokemon: Int(rand))
        
    }

}

