/*
 * This file is part of Clayground (https://github.com/MisterGC/clayground)
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software in
 *    a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Authors:
 * Copyright (c) 2019 Serein Pfeiffer <serein.pfeiffer@gmail.com>
 */
#include "svgwriter.h"
#include <simple-svg-writer/simple_svg.h>
#include <QFile>
#include <QTextStream>
#include <QDebug>

using namespace simple_svg;

SvgWriter::SvgWriter() : document_(new Document(""))
{}

SvgWriter::~SvgWriter() = default;


void SvgWriter::begin(float widthWu, float heightWu)
{
    Dimensions dimensions(static_cast<double>(widthWu),
                          static_cast<double>(heightWu));
    document_.reset(new Document(pathToSvg_.toStdString(),
                                 Layout(dimensions, Layout::mm, Layout::BottomLeft)));
}

void SvgWriter::rectangle(double x,
                          double y,
                          double width,
                          double height,
                          const QString &description)
{
    auto r = Rectangle(Point(x, y), width, height, Color::Black);
    r.setDescription(description.toHtmlEscaped().toStdString());
    *document_ << r;
}

void SvgWriter::circle(double x,
                       double y,
                       double radius,
                       const QString & description)
{
    auto r = Circle(Point(x,y), radius, Color::Black);
    r.setDescription(description.toHtmlEscaped().toStdString());
    *document_ << r;
}

void SvgWriter::end()
{
    document_->save();
}

void SvgWriter::setPath(const QString& pathToSvg)
{
    if (pathToSvg != pathToSvg_) {
        pathToSvg_ = pathToSvg;
        emit pathChanged();
    }
}

QString SvgWriter::path() const
{
    return pathToSvg_;
}
