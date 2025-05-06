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

signals:
    void sizeChanged();
    void faceScaleChanged();
    void scaledFaceChanged();

    // Edge rendering signals
    void showEdgesChanged();
    void edgeThicknessChanged();
    void edgeColorFactorChanged();

private:
    void updateData();
    QVector3D m_size;
    QVector2D m_faceScale;
    ScaledFace m_scaledFace;

    // Edge rendering properties with default values
    bool m_showEdges = true;
    float m_edgeThickness = 0.03f;
    float m_edgeColorFactor = 0.4f;
};

#endif // BOX3DGEOMETRY_H
