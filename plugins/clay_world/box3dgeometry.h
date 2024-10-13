#ifndef BOX3DGEOMETRY_H
#define BOX3DGEOMETRY_H

#include <QQuick3DGeometry>
#include <QVector3D>
#include <QVector2D>

class Box3dGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Box3dGeometry)

    Q_PROPERTY(QVector3D size READ size WRITE setSize NOTIFY sizeChanged)
    Q_PROPERTY(QVector2D faceScale READ faceScale WRITE setFaceScale NOTIFY faceScaleChanged)
    Q_PROPERTY(ScaledFace scaledFace READ scaledFace WRITE setScaledFace NOTIFY scaledFaceChanged)

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

signals:
    void sizeChanged();
    void faceScaleChanged();
    void scaledFaceChanged();

private:
    void updateData();
    QVector3D m_size;
    QVector2D m_faceScale;
    ScaledFace m_scaledFace;
};

#endif // BOX3DGEOMETRY_H
