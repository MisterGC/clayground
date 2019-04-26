cmake_minimum_required (VERSION 3.5.0 FATAL_ERROR)
project (box2dplugin)

set(CMAKE_AUTOMOC ON)
set (CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/plugins/Box2D)
set (CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/plugins/Box2D)

find_package(Qt5 REQUIRED COMPONENTS Quick Core Qml)

add_library(
Box2D SHARED
    
    # Box2D sources
    qml-box2d/Box2D/Box2D.h 
    qml-box2d/Box2D/Collision/Shapes/b2ChainShape.cpp 
    qml-box2d/Box2D/Collision/Shapes/b2ChainShape.h 
    qml-box2d/Box2D/Collision/Shapes/b2CircleShape.cpp 
    qml-box2d/Box2D/Collision/Shapes/b2CircleShape.h 
    qml-box2d/Box2D/Collision/Shapes/b2EdgeShape.cpp 
    qml-box2d/Box2D/Collision/Shapes/b2EdgeShape.h 
    qml-box2d/Box2D/Collision/Shapes/b2PolygonShape.cpp 
    qml-box2d/Box2D/Collision/Shapes/b2PolygonShape.h 
    qml-box2d/Box2D/Collision/Shapes/b2Shape.h 
    qml-box2d/Box2D/Collision/b2BroadPhase.cpp 
    qml-box2d/Box2D/Collision/b2BroadPhase.h 
    qml-box2d/Box2D/Collision/b2CollideCircle.cpp 
    qml-box2d/Box2D/Collision/b2CollideEdge.cpp 
    qml-box2d/Box2D/Collision/b2CollidePolygon.cpp 
    qml-box2d/Box2D/Collision/b2Collision.cpp 
    qml-box2d/Box2D/Collision/b2Collision.h 
    qml-box2d/Box2D/Collision/b2Distance.cpp 
    qml-box2d/Box2D/Collision/b2Distance.h 
    qml-box2d/Box2D/Collision/b2DynamicTree.cpp 
    qml-box2d/Box2D/Collision/b2DynamicTree.h 
    qml-box2d/Box2D/Collision/b2TimeOfImpact.cpp 
    qml-box2d/Box2D/Collision/b2TimeOfImpact.h 
    qml-box2d/Box2D/Common/b2BlockAllocator.cpp 
    qml-box2d/Box2D/Common/b2BlockAllocator.h 
    qml-box2d/Box2D/Common/b2Draw.cpp 
    qml-box2d/Box2D/Common/b2Draw.h 
    qml-box2d/Box2D/Common/b2GrowableStack.h 
    qml-box2d/Box2D/Common/b2Math.cpp 
    qml-box2d/Box2D/Common/b2Math.h 
    qml-box2d/Box2D/Common/b2Settings.cpp 
    qml-box2d/Box2D/Common/b2Settings.h 
    qml-box2d/Box2D/Common/b2StackAllocator.cpp 
    qml-box2d/Box2D/Common/b2StackAllocator.h 
    qml-box2d/Box2D/Common/b2Timer.cpp 
    qml-box2d/Box2D/Common/b2Timer.h 
    qml-box2d/Box2D/Dynamics/Contacts/b2ChainAndCircleContact.cpp 
    qml-box2d/Box2D/Dynamics/Contacts/b2ChainAndCircleContact.h 
    qml-box2d/Box2D/Dynamics/Contacts/b2ChainAndPolygonContact.cpp 
    qml-box2d/Box2D/Dynamics/Contacts/b2ChainAndPolygonContact.h 
    qml-box2d/Box2D/Dynamics/Contacts/b2CircleContact.cpp 
    qml-box2d/Box2D/Dynamics/Contacts/b2CircleContact.h 
    qml-box2d/Box2D/Dynamics/Contacts/b2Contact.cpp 
    qml-box2d/Box2D/Dynamics/Contacts/b2Contact.h 
    qml-box2d/Box2D/Dynamics/Contacts/b2ContactSolver.cpp 
    qml-box2d/Box2D/Dynamics/Contacts/b2ContactSolver.h 
    qml-box2d/Box2D/Dynamics/Contacts/b2EdgeAndCircleContact.cpp 
    qml-box2d/Box2D/Dynamics/Contacts/b2EdgeAndCircleContact.h 
    qml-box2d/Box2D/Dynamics/Contacts/b2EdgeAndPolygonContact.cpp 
    qml-box2d/Box2D/Dynamics/Contacts/b2EdgeAndPolygonContact.h 
    qml-box2d/Box2D/Dynamics/Contacts/b2PolygonAndCircleContact.cpp 
    qml-box2d/Box2D/Dynamics/Contacts/b2PolygonAndCircleContact.h 
    qml-box2d/Box2D/Dynamics/Contacts/b2PolygonContact.cpp 
    qml-box2d/Box2D/Dynamics/Contacts/b2PolygonContact.h 
    qml-box2d/Box2D/Dynamics/Joints/b2DistanceJoint.cpp 
    qml-box2d/Box2D/Dynamics/Joints/b2DistanceJoint.h 
    qml-box2d/Box2D/Dynamics/Joints/b2FrictionJoint.cpp 
    qml-box2d/Box2D/Dynamics/Joints/b2FrictionJoint.h 
    qml-box2d/Box2D/Dynamics/Joints/b2GearJoint.cpp 
    qml-box2d/Box2D/Dynamics/Joints/b2GearJoint.h 
    qml-box2d/Box2D/Dynamics/Joints/b2Joint.cpp 
    qml-box2d/Box2D/Dynamics/Joints/b2Joint.h 
    qml-box2d/Box2D/Dynamics/Joints/b2MotorJoint.cpp
    qml-box2d/Box2D/Dynamics/Joints/b2MotorJoint.h 
    qml-box2d/Box2D/Dynamics/Joints/b2MouseJoint.cpp 
    qml-box2d/Box2D/Dynamics/Joints/b2MouseJoint.h 
    qml-box2d/Box2D/Dynamics/Joints/b2PrismaticJoint.cpp 
    qml-box2d/Box2D/Dynamics/Joints/b2PrismaticJoint.h 
    qml-box2d/Box2D/Dynamics/Joints/b2PulleyJoint.cpp 
    qml-box2d/Box2D/Dynamics/Joints/b2PulleyJoint.h 
    qml-box2d/Box2D/Dynamics/Joints/b2RevoluteJoint.cpp 
    qml-box2d/Box2D/Dynamics/Joints/b2RevoluteJoint.h 
    qml-box2d/Box2D/Dynamics/Joints/b2RopeJoint.cpp 
    qml-box2d/Box2D/Dynamics/Joints/b2RopeJoint.h 
    qml-box2d/Box2D/Dynamics/Joints/b2WeldJoint.cpp 
    qml-box2d/Box2D/Dynamics/Joints/b2WeldJoint.h 
    qml-box2d/Box2D/Dynamics/Joints/b2WheelJoint.cpp 
    qml-box2d/Box2D/Dynamics/Joints/b2WheelJoint.h 
    qml-box2d/Box2D/Dynamics/b2Body.cpp 
    qml-box2d/Box2D/Dynamics/b2Body.h 
    qml-box2d/Box2D/Dynamics/b2ContactManager.cpp 
    qml-box2d/Box2D/Dynamics/b2ContactManager.h 
    qml-box2d/Box2D/Dynamics/b2Fixture.cpp 
    qml-box2d/Box2D/Dynamics/b2Fixture.h 
    qml-box2d/Box2D/Dynamics/b2Island.cpp 
    qml-box2d/Box2D/Dynamics/b2Island.h 
    qml-box2d/Box2D/Dynamics/b2TimeStep.h 
    qml-box2d/Box2D/Dynamics/b2World.cpp 
    qml-box2d/Box2D/Dynamics/b2World.h 
    qml-box2d/Box2D/Dynamics/b2WorldCallbacks.cpp 
    qml-box2d/Box2D/Dynamics/b2WorldCallbacks.h 
    qml-box2d/Box2D/Rope/b2Rope.cpp 
    qml-box2d/Box2D/Rope/b2Rope.h 

    # Qml-Box2d
    qml-box2d/box2dbody.cpp
    qml-box2d/box2dbody.h
    qml-box2d/box2dcontact.cpp
    qml-box2d/box2dcontact.h
    qml-box2d/box2ddebugdraw.cpp
    qml-box2d/box2ddebugdraw.h
    qml-box2d/box2ddistancejoint.cpp
    qml-box2d/box2ddistancejoint.h
    qml-box2d/box2dfixture.cpp
    qml-box2d/box2dfixture.h
    qml-box2d/box2dfrictionjoint.cpp
    qml-box2d/box2dfrictionjoint.h
    qml-box2d/box2dgearjoint.cpp
    qml-box2d/box2dgearjoint.h
    qml-box2d/box2djoint.cpp
    qml-box2d/box2djoint.h
    qml-box2d/box2dmotorjoint.cpp
    qml-box2d/box2dmotorjoint.h
    qml-box2d/box2dmousejoint.cpp
    qml-box2d/box2dmousejoint.h
    qml-box2d/box2dplugin.cpp
    qml-box2d/box2dplugin.h
    qml-box2d/box2dprismaticjoint.cpp
    qml-box2d/box2dprismaticjoint.h
    qml-box2d/box2dpulleyjoint.cpp
    qml-box2d/box2dpulleyjoint.h
    qml-box2d/box2draycast.cpp
    qml-box2d/box2draycast.h
    qml-box2d/box2drevolutejoint.cpp
    qml-box2d/box2drevolutejoint.h
    qml-box2d/box2dropejoint.cpp
    qml-box2d/box2dropejoint.h
    qml-box2d/box2dweldjoint.cpp
    qml-box2d/box2dweldjoint.h
    qml-box2d/box2dwheeljoint.cpp
    qml-box2d/box2dwheeljoint.h
    qml-box2d/box2dworld.cpp
    qml-box2d/box2dworld.h
    qml-box2d/qmldir
    )

set_target_properties (
Box2D
PROPERTIES
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS NO
)

target_include_directories( 
Box2D
PRIVATE
    qml-box2d
    qml-box2d/Box2D
)

target_link_libraries(
Box2D
PRIVATE
    Qt5::Core
    Qt5::Quick
    Qt5::Qml
)

add_custom_command(TARGET Box2D POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy
    ${CMAKE_CURRENT_SOURCE_DIR}/qml-box2d/qmldir
    ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/qmldir
)
