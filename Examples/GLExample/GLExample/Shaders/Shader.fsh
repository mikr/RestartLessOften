//
//  Shader.fsh
//  GLExample
//
//  Created by michael on 12/6/13.
//  Copyright (c) 2013 Michael Krause. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
