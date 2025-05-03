#ifndef BOX3DGEOMETRY_H
#define BOX3DGEOMETRY_H

#include <QQuick3DGeometry>
#include <QVector3D>
#include <QVector2D>

class Box3dGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Box3DGeometry)

    Q_PROPERTY(QVector3D size READ size WRITE setSize NOTIFY sizeChanged)
    Q_PROPERTY(QVector2D faceScale READ faceScale WRITE setFaceScale NOTIFY faceScaleChanged)
    Q_PROPERTY(ScaledFace scaledFace READ scaledFace WRITE setScaledFace NOTIFY scaledFaceChanged)

    // Edge rendering properties (matching VoxelMap)
    Q_PROPERTY(bool showEdges READ showEdges WRITE setShowEdges NOTIFY showEdgesChanged)
    Q_PROPERTY(float edgeThickness READ edgeThickness WRITE setEdgeThickness NOTIFY edgeThicknessChanged)
    Q_PROPERTY(float edgeColorFactor READ edgeColorFactor WRITE setEdgeColorFactor NOTIFY edgeColorFactorChanged)
    Q_PROPERTY(int edgeMask READ edgeMask WRITE setEdgeMask NOTIFY edgeMaskChanged)

public:
    enum ScaledFace {
        NoFace,
        TopFace,
        BottomFace,
        FrontFace,
        BackFace,
        LeftFace,
        RightFace
    };
    Q_ENUM(ScaledFace)

    // Edge mask constants for each face (bit positions)
    enum EdgeFlags {
        // Single bit constants
        Right_Bottom = 0x01,    // bit 0
        Left_Bottom = 0x02,     // bit 1
        Right_Top = 0x04,       // bit 2
        Left_Top = 0x08,        // bit 3
        Right_Top2 = 0x10,      // bit 4
        Left_Top2 = 0x20,       // bit 5
        Right_Left = 0x40,      // bit 6
        Left_Right = 0x80,      // bit 7

        // Combined face masks
        BottomEdges = 0x03,     // 00000011 - Bottom face edges (Right_Bottom | Left_Bottom)
        TopEdges = 0x3C,        // 00111100 - Top face edges
        FrontEdges = 0x8B,      // 10001011 - Front face edges
        BackEdges = 0x74,       // 01110100 - Back face edges
        LeftEdges = 0xAA,       // 10101010 - Left face edges
        RightEdges = 0x55,      // 01010101 - Right face edges
        AllEdges = 0xFF         // 11111111 - All edges
    };
    Q_ENUM(EdgeFlags)

    Box3dGeometry();

    QVector3D size() const;
    void setSize(const QVector3D &newSize);

    QVector2D faceScale() const;
    void setFaceScale(const QVector2D &newFaceScale);

    ScaledFace scaledFace() const;
    void setScaledFace(ScaledFace newScaledFace);

    // Edge rendering getters and setters
    bool showEdges() const;
    void setShowEdges(bool show);

    float edgeThickness() const;
    void setEdgeThickness(float thickness);

    float edgeColorFactor() const;
    void setEdgeColorFactor(float factor);

    int edgeMask() const;
    void setEdgeMask(int mask);

signals:
    void sizeChanged();
    void faceScaleChanged();
    void scaledFaceChanged();

    // Edge rendering signals
    void showEdgesChanged();
    void edgeThicknessChanged();
    void edgeColorFactorChanged();
    void edgeMaskChanged();

private:
    void updateData();
    QVector3D m_size;
    QVector2D m_faceScale;
    ScaledFace m_scaledFace;

    // Edge rendering properties with default values
    bool m_showEdges = true;
    float m_edgeThickness = 0.03f;
    float m_edgeColorFactor = 0.4f;
    int m_edgeMask = AllEdges;  // Default to showing all edges
};

#endif // BOX3DGEOMETRY_H
