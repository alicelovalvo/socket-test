//
//  NetworkInterfaces.
//  iPrycam
//
//  Created by Natale Galioto on 15/03/2020.
//  Copyright © 2020 Prysmian Electronics. All rights reserved.
//

#ifndef NetworkInterface_h
#define NetworkInterface_h

#include <string>

struct NetworkInterface {
    std::string name;
    std::string address;
    std::string mask;
    std::string broadcast;
};

#endif /* NetworkInterface_h */
