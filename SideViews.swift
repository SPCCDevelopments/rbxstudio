//
//  SideViews.swift
//  RobloxStudioMobile
//
//  Created by Andy Lin on 3/28/21.
//

import SwiftUI

struct mainListView: View{
    let tree: [RbxNode]
    @EnvironmentObject var propertyInfo: PropertyInfoArray

    var body: some View{
        List(tree, children: \.children){ node in
            Button(action:{
                propertyInfo.properties = node.decodeProps()
                propertyInfo.id = UUID()
                propertyInfo.name = node.name
            }){
                Text(node.name)
                    .foregroundColor(Color(UIColor.label))
            }
        }
    }
}

struct PropertyView: View{
    @EnvironmentObject var properties: PropertyInfoArray
    @EnvironmentObject var script: ScriptFile
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    var body: some View{
        if properties.properties.count == 0{
            VStack{
                Spacer()
                Text("No Element Selected")
                    .font(.title)
                Spacer()
            }
        }else{
            NavigationView{
                List{
                    ForEach(properties.properties, id: \.self){property in
                        PropertyCell(property: property)
                    }
                }
                .navigationBarTitle("Properties - \(properties.name)", displayMode: .inline)
                .navigationBarHidden(sizeClass == .compact)
            }
            .environmentObject(properties)
            .environmentObject(script)
        }
    }
}

struct PropertyCell: View{
    @State var newPropertyValue: Array<OrderedDict> = []
    @EnvironmentObject var properties: PropertyInfoArray
    @EnvironmentObject var scriptData: ScriptFile
    let property: PropertyInfo
    
    init(property: PropertyInfo){
        self.property = property
    }
    
    var body: some View{
        if property.type == "Array"{
            DisclosureGroup{
                ForEach(0..<newPropertyValue.count, id: \.self){indice in
                    HStack{
                        Text(property.value[indice].key)
                        TextField("", text: $newPropertyValue[indice].value)
                            .onChange(of: newPropertyValue[indice].value){_ in
                                properties.properties[property.id].value[indice].value = newPropertyValue[indice].value
                            }
                    }
                }
            } label: {
                Text(property.name)
            }
            .environmentObject(properties)
            .onAppear(){
                self.newPropertyValue = property.value
            }
            .onChange(of: property.value){_ in
                self.newPropertyValue = property.value
            }
        }else if property.value.count > 0{
            HStack{
                Text(property.name)
                ForEach(0..<newPropertyValue.count, id: \.self){indice in
                    TextField("", text: $newPropertyValue[indice].value)
                        .onChange(of: newPropertyValue[indice].value){_ in
                            if properties.properties.count > property.id{
                                properties.properties[property.id].value[indice].value = newPropertyValue[indice].value
                            }
                        }
                }
            }
            .environmentObject(properties)
            .environmentObject(scriptData)
            .onAppear(){
                self.newPropertyValue = property.value
                if property.name == "Source"{
                    print(property.value[0].value)
                    scriptData.file = property.value[0].value
                }
            }
            .onChange(of: property.value){_ in
                self.newPropertyValue = property.value
                if property.name == "Source"{
                    print(property.value[0].value)
                    scriptData.file = property.value[0].value
                }
            }
        }
    }
}
